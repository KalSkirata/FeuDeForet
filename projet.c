#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
// for Linux platform, plz make sure the size of data type is correct for BMP spec.
// if you use this on Windows or other platforms, plz pay attention to this.
typedef int LONG;
typedef unsigned char BYTE;
typedef unsigned int DWORD;
typedef unsigned short WORD;

// __attribute__((packed)) on non-Intel arch may cause some unexpected error, plz be informed.

typedef struct tagBITMAPFILEHEADER
{
    WORD    bfType; // 2  /* Magic identifier */
    DWORD   bfSize; // 4  /* File size in bytes */
    WORD    bfReserved1; // 2
    WORD    bfReserved2; // 2
    DWORD   bfOffBits; // 4 /* Offset to image data, bytes */ 
} __attribute__((packed)) BITMAPFILEHEADER;

typedef struct tagBITMAPINFOHEADER
{
    DWORD    biSize; // 4 /* Header size in bytes */
    LONG     biWidth; // 4 /* Width of image */
    LONG     biHeight; // 4 /* Height of image */
    WORD     biPlanes; // 2 /* Number of colour planes */
    WORD     biBitCount; // 2 /* Bits per pixel */
    DWORD    biCompress; // 4 /* Compression type */
    DWORD    biSizeImage; // 4 /* Image size in bytes */
    LONG     biXPelsPerMeter; // 4
    LONG     biYPelsPerMeter; // 4 /* Pixels per meter */
    DWORD    biClrUsed; // 4 /* Number of colours */ 
    DWORD    biClrImportant; // 4 /* Important colours */ 
} __attribute__((packed)) BITMAPINFOHEADER;

/*
typedef struct tagRGBQUAD
{
    unsigned char    rgbBlue;   
    unsigned char    rgbGreen;
    unsigned char    rgbRed;  
    unsigned char    rgbReserved;
} RGBQUAD;
* for biBitCount is 16/24/32, it may be useless
*/

typedef struct
{
        BYTE    b;
        BYTE    g;
        BYTE    r;
} RGB_data; // RGB TYPE, plz also make sure the order

int bmp_generator(char *filename, int width, int height, unsigned char *data)
{
    BITMAPFILEHEADER bmp_head;
    BITMAPINFOHEADER bmp_info;
    int size = width * height * 3;

    bmp_head.bfType = 0x4D42; // 'BM'
    bmp_head.bfSize= size + sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER); // 24 + head + info no quad    
    bmp_head.bfReserved1 = bmp_head.bfReserved2 = 0;
    bmp_head.bfOffBits = bmp_head.bfSize - size;
    // finish the initial of head

    bmp_info.biSize = 40;
    bmp_info.biWidth = width;
    bmp_info.biHeight = height;
    bmp_info.biPlanes = 1;
    bmp_info.biBitCount = 24; // bit(s) per pixel, 24 is true color
    bmp_info.biCompress = 0;
    bmp_info.biSizeImage = size;
    bmp_info.biXPelsPerMeter = 0;
    bmp_info.biYPelsPerMeter = 0;
    bmp_info.biClrUsed = 0 ;
    bmp_info.biClrImportant = 0;
    // finish the initial of infohead;

    // copy the data
    FILE *fp;
    if (!(fp = fopen(filename,"wb"))) return 0;

    fwrite(&bmp_head, 1, sizeof(BITMAPFILEHEADER), fp);
    fwrite(&bmp_info, 1, sizeof(BITMAPINFOHEADER), fp);
    fwrite(data, 1, size, fp);
    fclose(fp);

    return 1;
}

RGB_data woods;
RGB_data ground;
RGB_data fire;

RGB_data buffer[256][256];

void init_color(){
	woods.b=0;
	woods.g=204;
	woods.r=0;
	
	ground.b=0;
	ground.g=51;
	ground.r=102;
	
	fire.b=0;
	fire.g=0;
	fire.r=255;
}

void put_fire(){
	/*if(x<0 || x>256) return;
	if(y<0 || y>256) return;
	if(buffer[x][y].r==woods.r && buffer[x][y].g==woods.g && buffer[x][y].b==woods.b){
		buffer[x][y].r=fire.r;
		buffer[x][y].b=fire.b;
		buffer[x][y].g=fire.g;
		
	usleep(20000);
	bmp_generator("./test.bmp", 256, 256, (BYTE*)buffer);		
	put_fire(x-1, y);
	bmp_generator("./test.bmp", 256, 256, (BYTE*)buffer);	
	put_fire(x+1, y);
	bmp_generator("./test.bmp", 256, 256, (BYTE*)buffer);	
	put_fire(x, y-1);
	bmp_generator("./test.bmp", 256, 256, (BYTE*)buffer);	
	put_fire(x, y+1);
	bmp_generator("./test.bmp", 256, 256, (BYTE*)buffer);
	}*/
	
	int x,y;
	while(1){
		for(x=0; x<256; x++){
			for(y=0; y<256; y++){
				if(buffer[x][y].g==woods.g){
					if(x>0 && x<256){
						if(buffer[x-1][y].r==fire.r || buffer[x+1][y].r==fire.r){
							buffer[x][y].r=fire.r;
							buffer[x][y].g=fire.g;
							buffer[x][y].b=fire.b;
						}
					}else if(y>0 && y<256){
							if(buffer[x][y-1].r==fire.r || buffer[x][y+1].r==fire.r){
							buffer[x][y].r=fire.r;
							buffer[x][y].g=fire.g;
							buffer[x][y].b=fire.b;
						}
					}
				}
			}
		}
		bmp_generator("./test.bmp", 256, 256, (BYTE*)buffer);
	}
	
}

int main(int argc, char **argv)
{
    int i,j,r,x,y;
    
    init_color();

    memset(buffer, 0, sizeof(buffer));

	srand(time(NULL));
    for (i = 0; i < 256; i++)
    {
        for (j = 0; j < 256; j++)
        {
        	r=rand()%10;
        	if(r < 7){
            	buffer[i][j].g = woods.g;
            	buffer[i][j].b = woods.b;
            	buffer[i][j].r = woods.r;
            }else{
            	buffer[i][j].g = ground.g;
            	buffer[i][j].b = ground.b;
            	buffer[i][j].r = ground.r;
            }
            //buffer[i][j].r=buffer[i][j].g=buffer[i][j].b=0;
        }
    }

    bmp_generator("./test.bmp", 256, 256, (BYTE*)buffer);
    
	x=rand()%256;
	y=rand()%256;
	
	while(buffer[x][y].g==ground.g){
		x=rand()%256;
		y=rand()%256;
	}
	printf("x=%d y=%d \n",x,y);
    buffer[x][y].r=fire.r;
    buffer[x][y].g=fire.g;
    buffer[x][y].b=fire.b;
    
    bmp_generator("./test.bmp", 256, 256, (BYTE*)buffer);

	put_fire();

    return 0;
}
