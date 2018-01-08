using OpenTK.Graphics.OpenGL;
using System;
using System.Diagnostics;
using System.IO;

namespace Template
{
    internal class Game
    {
        // when GLInterop is set to true, the fractal is rendered directly to an OpenGL texture
        private bool GLInterop = true;

        // load the OpenCL program; this creates the OpenCL context
        private static OpenCLProgram ocl = new OpenCLProgram("../../program.cl");

        // find the kernel named 'device_function' in the program
        private OpenCLKernel kernel = new OpenCLKernel(ocl, "device_function");

        // create a regular buffer; by default this resides on both the host and the device
        private OpenCLBuffer<int> buffer = new OpenCLBuffer<int>(ocl, 512 * 512);

        // create an OpenGL texture to which OpenCL can send data
        private OpenCLImage<int> image = new OpenCLImage<int>(ocl, 512, 512);

        public Surface screen;
        private Stopwatch timer = new Stopwatch();
        private float t = 21.5f;

        public void Init()
        {
            readGoLFile();
            patternData = new OpenCLBuffer<uint>(ocl, (int)(pw * ph));
            secondData = new OpenCLBuffer<uint>(ocl, (int)(pw * ph));
        }

        private static uint[] pattern;
        private static uint[] second;
        private OpenCLBuffer<uint> patternData, secondData;
        private uint pw, ph;

        private void BitSet(uint x, uint y)
        { pattern[y * pw + (x >> 5)] |= 1U << (int)(x & 31); }

        private uint GetBit(uint x, uint y)
        { return (second[y * pw + (x >> 5)] >> (int)(x & 31)) & 1U; }

        public void readGoLFile()
        {
            StreamReader sr = new StreamReader("../../data/turing_js_r.rle");
            uint state = 0, n = 0, x = 0, y = 0;
            while (true)
            {
                String line = sr.ReadLine();
                if (line == null) break; // end of file
                int pos = 0;
                if (line[pos] == '#') continue; /* comment line */
                else if (line[pos] == 'x') // header
                {
                    String[] sub = line.Split(new char[] { '=', ',' }, StringSplitOptions.RemoveEmptyEntries);
                    pw = (UInt32.Parse(sub[1]) + 31) / 32;
                    ph = UInt32.Parse(sub[3]);
                    pattern = new uint[pw * ph];
                    second = new uint[pw * ph];
                }
                else while (pos < line.Length)
                    {
                        Char c = line[pos++];
                        if (state == 0) if (c < '0' || c > '9') { state = 1; n = Math.Max(n, 1); } else n = (uint)(n * 10 + (c - '0'));
                        if (state == 1) // expect other character
                        {
                            if (c == '$') { y += n; x = 0; } // newline
                            else if (c == 'o') for (int i = 0; i < n; i++) BitSet(x++, y); else if (c == 'b') x += n;
                            state = n = 0;
                        }
                    }
            }
            // swap buffers
            for (int i = 0; i < pw * ph; i++) second[i] = pattern[i];
        }

        private void Simulate()
        {
            // clear destination pattern
            for (int i = 0; i < pw * ph; i++) pattern[i] = 0;
            // process all pixels, skipping one pixel boundary
            uint w = pw * 32, h = ph;
            for (uint y = 1; y < h - 1; y++) for (uint x = 1; x < w - 1; x++)
                {
                    // count active neighbors
                    uint n = GetBit(x - 1, y - 1) + GetBit(x, y - 1) + GetBit(x + 1, y - 1) + GetBit(x - 1, y) +
                                GetBit(x + 1, y) + GetBit(x - 1, y + 1) + GetBit(x, y + 1) + GetBit(x + 1, y + 1);
                    if ((GetBit(x, y) == 1 && n == 2) || n == 3) BitSet(x, y);
                }
            // swap buffers
            for (int i = 0; i < pw * ph; i++) second[i] = pattern[i];
        }

        public void Tick()
        {
            GL.Finish();
            Simulate();
            // clear the screen
            screen.Clear(0);
            // do opencl stuff
            if (GLInterop)
            {
                kernel.SetArgument(0, image);
            }
            else
            {
                kernel.SetArgument(0, buffer);
            }

            kernel.SetArgument(1, patternData);
            kernel.SetArgument(2, secondData);
            kernel.SetArgument(3, pw);
            kernel.SetArgument(4, ph);
            kernel.SetArgument(5, t);
            t += 0.1f;

            secondData.CopyFromDevice();
           


            // execute kernel
            long[] workSize = { 512, 512 };
            long[] localSize = { 32, 4 };
            if (GLInterop)
            {
                // INTEROP PATH:
                // Use OpenCL to fill an OpenGL texture; this will be used in the
                // Render method to draw a screen filling quad. This is the fastest
                // option, but interop may not be available on older systems.
                // lock the OpenGL texture for use by OpenCL
                kernel.LockOpenGLObject(image.texBuffer);
                // execute the kernel
                kernel.Execute(workSize, localSize);
                // unlock the OpenGL texture so it can be used for drawing a quad
                kernel.UnlockOpenGLObject(image.texBuffer);
            }
            else
            {
                // NO INTEROP PATH:
                // Use OpenCL to fill a C# pixel array, encapsulated in an
                // OpenCLBuffer<int> object (buffer). After filling the buffer, it
                // is copied to the screen surface, so the template code can show
                // it in the window.
                // execute the kernel
                kernel.Execute(workSize, localSize);
                // get the data from the device to the host
                buffer.CopyFromDevice();
                // plot pixels using the data on the host
                for (int y = 0; y < 512; y++) for (int x = 0; x < 512; x++)
                    {
                        screen.pixels[x + y * screen.width] = buffer[x + y * 512];
                    }
            }
        }

        public void Render()
        {
            // use OpenGL to draw a quad using the texture that was filled by OpenCL
            if (GLInterop)
            {
                GL.LoadIdentity();
                GL.BindTexture(TextureTarget.Texture2D, image.OpenGLTextureID);
                GL.Begin(PrimitiveType.Quads);
                GL.TexCoord2(0.0f, 1.0f); GL.Vertex2(-1.0f, -1.0f);
                GL.TexCoord2(1.0f, 1.0f); GL.Vertex2(1.0f, -1.0f);
                GL.TexCoord2(1.0f, 0.0f); GL.Vertex2(1.0f, 1.0f);
                GL.TexCoord2(0.0f, 0.0f); GL.Vertex2(-1.0f, 1.0f);
                GL.End();
            }
        }
    }
} // namespace Template