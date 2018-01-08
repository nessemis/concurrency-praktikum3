#define GLINTEROP


void BitSet( __global uint* buf, uint x, uint y, uint pw ) { buf[y * pw + (x >> 5)] |= 1 << (int)(x & 31); }

uint GetBit( __global uint* buf, uint x, uint y , uint pw) { return (buf[y * pw + (x >> 5)] >> (int)(x & 31)) & 1; }


#ifdef GLINTEROP
__kernel void device_function( write_only image2d_t a, __global uint* pat, __global uint* sec, uint pw, uint ph, float t )
#else
__kernel void device_function( __global int* a, __global uint* pat, __global uint* sec, uint pw, uint ph, float t )
#endif
{

	int idx = get_global_id( 0 );
	int idy = get_global_id( 1 );
	int id = idx + 512 * idy;
	if (id >= (512 * 512)) return;

	float3 col = (float3)( 0.f, 0.f, 0.f );

    if(GetBit(sec,(uint)idx,(uint)idy,pw)==1 )
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
