#define GLINTEROP


void BitSet( __global uint* buf, uint x, uint y, uint pw ) { buf[y * pw + (x >> 5)] |= 1 << (int)(x & 31); }

uint GetBit( __global uint* buf, uint x, uint y , uint pw) { return (buf[y * pw + (x >> 5)] >> (int)(x & 31)) & 1; }

uint UintGetBit( uint a, uint x) { return (a >> (int)(x & 31)) & 1; }

void Simulate( __global uint* pat , __global uint* sec, uint pw, uint ph, uint xc , uint yc)
{
    int height = ph;
    int width = pw * 32;

    if(yc > height -1 || yc < 1){return;}
	
	uint pat_buf = 0U;
    uint sec1 =  sec[(yc-1) * pw + (xc)];
    uint sec2 =  sec[(yc)   * pw + (xc)];
    uint sec3 =  sec[(yc+1) * pw + (xc)];
    
    uint x = xc *32;
    if(x < 1) return;
    uint n = GetBit(sec, x - 1, yc - 1 ,pw) + GetBit(sec ,x, yc - 1,pw) + GetBit(sec ,x + 1, yc - 1,pw) + GetBit(sec ,x - 1, yc,pw) +
        GetBit(sec,x + 1, yc,pw) + GetBit(sec,x - 1, yc + 1,pw) + GetBit(sec,x, yc + 1,pw) + GetBit(sec,x + 1, yc + 1,pw);
    if ((UintGetBit(sec2,x) == 1 && n == 2) || n == 3) 
            pat_buf |= 1 << x;
            
     x = xc *32 + 31 ;
     if(x > width -1 ) return;
     n = GetBit(sec, x - 1, yc - 1 ,pw) + GetBit(sec ,x, yc - 1,pw) + GetBit(sec ,x + 1, yc - 1,pw) + GetBit(sec ,x - 1, yc,pw) +
        GetBit(sec,x + 1, yc,pw) + GetBit(sec,x - 1, yc + 1,pw) + GetBit(sec,x, yc + 1,pw) + GetBit(sec,x + 1, yc + 1,pw);
    if ((UintGetBit(sec2,x) == 1 && n == 2) || n == 3) 
            pat_buf |= 1 << x;
    
    for(int i = 1; i < 31;i++){
        
        x = xc*32 + i;
       
        n = UintGetBit(sec1,x - 1) + 
                 UintGetBit(sec1,x) + 
                 UintGetBit(sec1,x + 1) + 
                 UintGetBit(sec2,x - 1) +
                 UintGetBit(sec2,x + 1) + 
                 UintGetBit(sec3,x - 1) + 
                 UintGetBit(sec3,x) + 
                 UintGetBit(sec3,x + 1);
        if ((UintGetBit(sec2,x) == 1 && n == 2) || n == 3) 
            pat_buf |= 1 << x;
    }
    
	pat[yc * pw + xc] = pat_buf;

    
}

__kernel void update_function(__global uint* pat, __global uint* sec, uint pw, uint ph){

    int idx = get_global_id( 0 );
	int idy = get_global_id( 1 );
	
    Simulate(pat, sec , pw, ph, idx, idy);

}

#ifdef GLINTEROP
__kernel void drawing_function( write_only image2d_t a ,__global uint* buf, uint pw, uint ph, int xoffset, int yoffset, float scroll)
#else
__kernel void drawing_function( __global int* a ,__global uint* buf, uint pw ,uint ph, int xoffset, int yoffset, float scroll )
#endif
{

    int idx = get_global_id( 0 );
	int idy = get_global_id( 1 );

    float xpos = (idx + ((256 + xoffset) / scroll) ) * scroll - 256 * scroll ;
    float ypos = (idy + ((256 + yoffset) / scroll) ) * scroll - 256 * scroll;
    
    float3 col = (float3)( 0.f, 0.f, 0.f );
    
    //Check not necessary (is done in csharp)
    if(!(xpos < 0 || ypos < 0 || xpos > pw *32 || ypos > ph)){        
    
    


    if(GetBit(buf,(uint)xpos,(uint)ypos,pw)==1 )
        col = (float3)(1.0f,1.0f,1.0);
    else
        col = (float3)(0.0f,0.0f,0.0f);
    }
    
    
    
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
