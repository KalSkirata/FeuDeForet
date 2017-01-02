#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "cuPrintf.cu"

#define N 16

#define TILE_width 16


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

#define TAB(t, x, y) (t)[(y)*width+(x)]

RGB_data woods;
RGB_data ground;
RGB_data fire;
RGB_data ash;

RGB_data buffer[256][256], *bufferGPU;

int cptFire=0;
int cptWoods=0;

int xGPU=-1;
int yGPU=-1;

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

  ash.b=128;
  ash.g=128;
  ash.r=128;
}


void init_grid(int width, int height, int percentage){
  int  i,j,r;
  srand(time(NULL));
  for (i = 0; i < width; i++)
    {
      for (j = 0; j < height; j++)
	{
	  r=rand()%10;
	  if(r < percentage/10){ //70% de chance que ce soit de la foret
	    buffer[i][j].g = woods.g;
	    buffer[i][j].b = woods.b;
	    buffer[i][j].r = woods.r;
	    cptWoods+=1;
	  }else{
	    buffer[i][j].g = ground.g;
	    buffer[i][j].b = ground.b;
	    buffer[i][j].r = ground.r;
	  }
	}
    }

  //bmp_generator("./test.bmp", width, height, (BYTE*)buffer);

}


void init_fire(int width, int height){

  int x,y;	

  srand(time(NULL));
  x=rand()%width;
  y=rand()%height;
	
  while(buffer[y][x].g==ground.g){
    x=rand()%width;
    y=rand()%height;
  }
  printf("init_fire : x=%d y=%d \n",x,y);

  buffer[y][x].r=fire.r;
  buffer[y][x].g=fire.g;
  buffer[y][x].b=fire.b;
  bmp_generator("./test.bmp", width, height, (BYTE*)buffer);

} 


void put_fireCPU(int width, int height){
	
  int x,y,left,right,down,up;
	
  for(y=0; y<height; y++){
    for(x=0; x<width; x++){	
      if (buffer[y][x].g==woods.g){
	//Contrôle dépassement tableau
	if(x<width-1){
	  right=x+1;
	}
			
	if(x>0){
	  left=x-1;
	}else{
	  left=0;			
	}
		
	if(y<height-1){
	  up=y+1;
	}

	if(y>0){
	  down=y-1;
	}else{
	  down=0;			
	}

	//On regarde les 4 cases à côté
	if( (buffer[up][x].r==fire.r) || (buffer[down][x].r==fire.r) || (buffer[y][right].r==fire.r) || (buffer[y][left].r==fire.r) ){

	  buffer[y][x].r=fire.r;
	  buffer[y][x].g=fire.g;
	  buffer[y][x].b=fire.b;
	  cptFire+=1;
	}
      }
    }
  }
}



__global__ void putFireGPU(RGB_data woods, RGB_data fire, RGB_data ash, int *cptFire,RGB_data *bufferGPU, int width, int height){
	
  uint x,y;
  int left,right,down,up;

  x=(blockIdx.x * blockDim.x) + threadIdx.x;
  y=(blockIdx.y * blockDim.y) + threadIdx.y;

  if (x >= width || y >= height) return;

  if (TAB(bufferGPU, x, y).g==woods.g){
    //Contrôle dépassement tableau
    if(x<width-1)
      right=x+1;
    else right = width-1;

    if(x>0){
      left=x-1;
    }else{
      left=0;			
    }
	  
    if(y<height-1)
      up=y+1;
    else up = height-1;
	  
    if(y>0){
      down=y-1;
    }else{
      down=0;			
    }

    //TODO improve

    if(TAB(bufferGPU, left, y).r==fire.r){
      //put current position in fire
      TAB(bufferGPU, x, y).r=fire.r;
      TAB(bufferGPU, x, y).g=fire.g;
      TAB(bufferGPU, x, y).b=fire.b;
      //TAB(cptFire,0,0)++;
      //put neighbour in ash
      TAB(bufferGPU, left, y).r=ash.r;
      TAB(bufferGPU, left, y).g=ash.g;
      TAB(bufferGPU, left, y).b=ash.b;
    }else if(TAB(bufferGPU, right, y).r==fire.r){      
      //put current position in fire
      TAB(bufferGPU, x, y).r=fire.r;
      TAB(bufferGPU, x, y).g=fire.g;
      TAB(bufferGPU, x, y).b=fire.b;
      //TAB(cptFire,0,0)++;
      //put neighbour in ash
      TAB(bufferGPU, right, y).r=ash.r;
      TAB(bufferGPU, right, y).g=ash.g;
      TAB(bufferGPU, right, y).b=ash.b;
    }else if(TAB(bufferGPU, x, up).r==fire.r){   
      //put current position in fire
      TAB(bufferGPU, x, y).r=fire.r;
      TAB(bufferGPU, x, y).g=fire.g;
      TAB(bufferGPU, x, y).b=fire.b;
      //TAB(cptFire,0,0)++;
      //put neighbour in ash
      TAB(bufferGPU, x, up).r=ash.r;
      TAB(bufferGPU, x, up).g=ash.g;
      TAB(bufferGPU, x, up).b=ash.b;
    }else if(TAB(bufferGPU, x, down).r==fire.r){   
      //put current position in fire
      TAB(bufferGPU, x, y).r=fire.r;
      TAB(bufferGPU, x, y).g=fire.g;
      TAB(bufferGPU, x, y).b=fire.b;
      //TAB(cptFire,0,0)++;
      //put neighbour in ash
      TAB(bufferGPU, x, down).r=ash.r;
      TAB(bufferGPU, x, down).g=ash.g;
      TAB(bufferGPU, x, down).b=ash.b;
    }
  }
}


int main(int argc, char **argv)
{

  //dim3 dimGrid(ceil((float)width/TILE_width), ceil((float)height/TILE_width));
  dim3 dimBlock(TILE_width, TILE_width, 1);
  int i;
  char test[16];

  double pourcentageFeu;

  while(argc < 3){
    printf("Usage : ./projet PERCENTAGE_WOODS PERCENTAGE_STOP \n - PERCENTAGE_WOODS : Percentage of woods at the initialization (0-100%)\n - PERCENTAGE_STOP : Percentage of fire to stop the spread \n");
    return -1;
  }

  int width = 256;
  int height = 256;
  int percentage_woods = atoi(argv[1]);
  int percentage_stop = atoi(argv[2]);
  
  dim3 dimGrid(ceil((float)width/TILE_width), ceil((float)height/TILE_width));

  //Initialisation du buffer (de l'image)
  memset(buffer, 0, sizeof(RGB_data) * size_t(height*width)); //CPU

  //Initialisation de la grille
  init_color();
  init_grid(width, height, 60);
  init_fire(width, height);

  cudaPrintfInit();

  //GPU
  cudaMalloc((void**)&bufferGPU,  sizeof(RGB_data) * size_t(height*width)); 
  cudaMemset(bufferGPU, 0,  sizeof(RGB_data) * size_t(height*width));

  cudaMemcpy(bufferGPU, buffer, sizeof(RGB_data) * size_t(height*width), cudaMemcpyHostToDevice);
  
  int* d_cptFire;
  cudaMalloc((void**)&d_cptFire, sizeof(int));
  cudaMemset(d_cptFire, 0, sizeof(int));
  i = 0;
  while (i<100){
    //put_fire();
    //printf("%d\n", i);
	  
    putFireGPU <<< dimGrid,dimBlock >>> (woods, fire, ash, d_cptFire, bufferGPU, width, height);
    cudaPrintfDisplay(stdout, true);
    cudaMemcpy(buffer,bufferGPU, sizeof(RGB_data) * size_t(height*width),cudaMemcpyDeviceToHost); 

    sprintf(test, "test%03d.bmp", i);
    i++;

    bmp_generator(test, width, height, (BYTE*)buffer);

    //int *h_cptFire;
    //cudaMemcpy(h_cptFire, d_cptFire, sizeof(int),cudaMemcpyDeviceToHost);
    //pourcentageFeu=((double)*h_cptFire/(double)width*height)*100.0;
    //printf("Poucentage feu: %f - cptFire=%d\n", pourcentageFeu, h_cptFire);
  }

  cudaPrintfEnd();
  printf("Propagation finie \n");

  cudaFree(bufferGPU);
  cudaFree(d_cptFire);

  return 0;
}
