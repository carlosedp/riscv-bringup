#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdint.h>
#include <stdlib.h>

#define SZ 64L*1024*1024
#define ALIGN (1024*1024)

char buf[SZ+SZ+ALIGN];

__attribute__((noinline))
void do_test(char *dst, char *src, long sz){
  memcpy(dst, src, sz);
}

void do_benchmark(char *dst, char *src, long sz){
  double sec;
  long repeat;
  //printf("Checking sz = %ld\n", sz);
  for (repeat=1; repeat<=(1L<<60); repeat<<=1){
    clock_t start = clock();
    for (long i=0; i<repeat; ++i) do_test(dst, src, sz);
    sec = (clock() - start) / (double)CLOCKS_PER_SEC;
    //printf("%9ld : %20ld %10.6f\n", sz, repeat, sec);
    if (sec > 1.0) break;
  }
  printf("%9ld : %15.1f  %8.1f MB/s\n", sz, sec*1000000000.0/repeat, sz/(sec*(1024*1024))*repeat);
  fflush(stdout);
}

int main(){
  char *foo = (char*)((((unsigned long)buf) + (ALIGN-1)) & ~(ALIGN-1));
  char *bar = foo + SZ;
  for (long i=0; i<SZ; ++i){
    long rnd = random() & 0xff;
    foo[i] = rnd;
  }
  do_test(bar, foo, SZ);
  for (long i=0; i<SZ; ++i){
    if (bar[i] != foo[i]){
      printf("Test memcpy failed\n");
      return 1;
    }
  }
  printf("Byte size :              ns     Speed\n");
  do_benchmark(foo, bar, 0);
  for (long sz=1; sz <= SZ; sz<<=1)
    do_benchmark(bar, foo, sz);
  return 0;
}

