#define GLINTEROP


void BitSet( __global uint* buf, uint x, uint y, uint pw ) { buf[y * pw + (x >> 5)] |= 1 << (int)(x & 31); }

uint GetBit( __global uint* buf, uint x, uint y , uint pw) { return (buf[y * pw + (x >> 5)] >> (int)(x & 31)) & 1; }

void Simulate( __global uint* pat , __global uint* sec, uint pw, uint ph, uint xc , uint yc)
{
    int height = ph;
    int width = pw * 32;

    pat[yc * pw + (xc >> 5)] &= ~(1 << (int)(xc & 31));

    if(xc > width -1 || yc > height -1 || xc < 1 || yc < 1){return;} 


    uint n = GetBit(sec, xc - 1, yc - 1 ,pw) + GetBit(sec ,xc, yc - 1,pw) + GetBit(sec ,xc + 1, yc - 1,pw) + GetBit(sec ,xc - 1, yc,pw) +
                GetBit(sec,xc + 1, yc,pw) + GetBit(sec,xc - 1, yc + 1,pw) + GetBit(sec,xc, yc + 1,pw) + GetBit(sec,xc + 1, yc + 1,pw);
    if ((GetBit(sec,xc, yc ,pw) == 1 && n == 2) || n == 3) BitSet(pat,xc , yc,pw);
        

}



#ifdef GLINTEROP
__kernel void device_function( write_only image2d_t a, __global uint* pat, __global uint* sec, uint pw, uint ph, float t )
#else
__kernel void device_function( __global int* a, __global uint* pat, __global uint* sec, uint pw, uint ph, float t )
#endif
{


	int idx = get_global_id( 0 );
	int idy = get_global_id( 1 );
	
    Simulate(pat, sec , pw, ph, idx, idy);
    
    
	if (idx >= 512 || idy >= 512) return;

    
    
    
	float3 col = (float3)( 0.f, 0.f, 0.f );

    if(GetBit(pat,(uint)idx,(uint)idy,pw)==1 )
        col = (float3)(1.0f,1.0f,1.0);
    else
        col = (float3)(0.0f,0.0f,0.0f);
    
    
    
    
#ifdef GLINTEROP
	int2 pos = (int2)(idx,idy);
	write_imagef( a, pos, (float4)(col , 1.0f ) );
#else
	int r = (int)clamp(  col.x, 0.f, 255.f );
	int g = (int)clamp(  col.y, 0.f, 255.f );
	int b = (int)clamp(  col.z, 0.f, 255.f );
	a[id] = (r << 16) + (g << 8) + b;
#endif
}
