// Copyright 2016-2020 Bruce hoult bruce@hoult.org
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Program to count primes. I wanted something that could run in 16 KB but took enough
// time to measure on a modern x86 and is not susceptible to optimizer tricks.
// Code size is for just the countPrimes() function with gcc -O.
//
// Original x86&ARM data 2016, received user contributions 2019&2020 from eevblog members.
//
// SZ = 1000 -> 3713160 primes, all primes up to 7919^2 = 62710561
//     2.735 sec i7 8650U @ 4.2 GHz                  242 bytes  11.5 billion clocks
//     2.795 sec Mac Mini M1 @ 3.2 GHz               212 bytes   8.9 billion clocks
//     2.810 sec Mac Mini M1 arm64 Ubuntu in VM      280 bytes   9.0 billion clocks
//     2.872 sec i7 6700K @ 4.2 GHz                  240 bytes  12.1 billion clocks
//     2.925 sec Mac Mini M1 @ 3.2 GHz Rosetta       208 bytes   9.4 billion clocks
//     3.448 sec Ryzen 5 4500U @ 4.0 GHz WSL2        242 bytes  13.8 billion clocks
//     3.505 sec Xeon Plat 8151 @ 4.0 GHz (AWS z1d)  244 bytes  14.0 billion clocks
//     3.515 sec Threadripper 2990WX @ 4.2 GHz       242 bytes  14.8 billion clocks
//     3.836 sec i7 4700MQ @ 3.4 GHz                 258 bytes  13.0 billion clocks
//     3.972 sec i7 8650U @ 4.2 GHz webasm           277 bytes  16.7 billion clocks
//     4.868 sec i7 3770  @ 3.9 GHz                  240 bytes  19.0 billion clocks
//     6.377 sec AWS C6g graviton2 A64 @ 2.5 GHz     276 bytes  15.9 billion clocks
//     6.757 sec M1 Mini, qemu-riscv64 in UbuntuVM   216 bytes  23.0 billion clocks
//     8.538 sec NXP LX2160A A72 @ 2 GHz             260 bytes  17.1 billion clocks
//     9.692 sec RISC-V Fedora in qemu in VM on M1   208 bytes  31.0 billion clocks
//     9.740 sec i7 6700K qemu-riscv32               178 bytes  40.9 billion clocks
//    10.046 sec i7 8650U @ 4.2 GHz qemu-riscv32     190 bytes  42.2 billion clocks
//    11.190 sec Pi4 Cortex A72 @ 1.5 GHz T32        232 bytes  16.8 billion clocks
//    11.445 sec Odroid XU4 A15 @ 2 GHz              204 bytes  22.9 billion clocks
//    12.115 sec Pi4 Cortex A72 @ 1.5 GHz A64        300 bytes  18.2 billion clocks
//    12.605 sec Pi4 Cortex A72 @ 1.5 GHz A32        300 bytes  18.9 billion clocks
//    13.721 sec RISC-V Fedora in qemu on 2990wx     208 bytes  57.6 billion clocks
//    17.394 sec RISCV U74 @1500 MHz (est vs FPGA)   228 bytes  26.1 billion clocks
//    19.500 sec Odroid C2 A53 @ 1.536 GHz A64       276 bytes  30.0 billion clocks
//    23.940 sec Odroid C2 A53 @ 1.536 GHz T32       204 bytes  36.8 billion clocks
//    24.636 sec i7 6700K qemu-arm                   204 bytes 103.5 billion clocks
//    25.060 sec i7 6700K qemu-aarch64               276 bytes 105.3 billion clocks
//    27.196 sec Teensy 4.0 Cortex M7 @ 960 MHz      228 bytes  26.1 billion clocks
//    27.480 sec HiFive Unl RISCV U54 @ 1.45 GHz     228 bytes  39.8 billion clocks
//    30.420 sec Pi3 Cortex A53 @ 1.2 GHz T32        204 bytes  36.5 billion clocks
//    39.840 sec HiFive Unl RISCV U54 @ 1.0 GHz      228 bytes  39.8 billion clocks
//    43.516 sec Teensy 4.0 Cortex M7 @ 600 MHz      228 bytes  26.1 billion clocks
//    47.910 sec Pi2 Cortex A7 @ 900 MHz T32         204 bytes  42.1 billion clocks
//    48.206 sec Zynq-7010 Cortex A9 @ 650MHz        248 bytes  31.3 billion clocks
//   112.163 sec HiFive1 RISCV E31 @ 320 MHz         178 bytes  35.9 billion clocks
//   260.907 sec RISCV U74 @ 100 MHz FPGA            228 bytes  26.1 billion clocks
//   261.068 sec esp32/Arduino @ 240 MHz             ??? bytes  62.7 billion clocks
//   294.749 sec chipKIT Pro MZ pic32 @ 200 MHz      ??? bytes  58.9 billion clocks
//   306.988 sec esp8266 @ 160 MHz                   ??? bytes  49.1 billion clocks
//   309.251 sec BlackPill Cortex M4F @ 168 MHz      228 bytes  52.0 billion clocks
//   927.547 sec BluePill Cortex M3 @ 72 MHz         228 bytes  66.8 billion clocks
// 13449.513 sec AVR ATmega2560 @ 20 MHz             318 bytes 269.0 billion clocks

#include <stdio.h>
#include <time.h>
#include <stdint.h>

#define SZ 1000
int32_t primes[SZ], sieve[SZ];
int nSieve = 0;

int32_t countPrimes(){
  primes[0] = 2; sieve[0] = 4; ++nSieve;
  int32_t nPrimes = 1, trial = 3, sqr=2;
  while (1){
    while (sqr*sqr <= trial) ++sqr;
    --sqr;
    for (int i=0; i<nSieve; ++i){
      if (primes[i] > sqr) goto found_prime;
      while (sieve[i] < trial) sieve[i] += primes[i];
      if (sieve[i] == trial) goto try_next;
    }
    break;
  found_prime:
    if (nSieve < SZ){
      primes[nSieve] = trial;
      sieve[nSieve] = trial*trial;
      ++nSieve;
      // printf("Saved %d: %d\n", nSieve, trial);
    }
    ++nPrimes;
  try_next:
    trial+=1;
  }
  return nPrimes;
}

int main(){
  printf("Starting run\n");
  clock_t start = clock();
  int res = countPrimes();
  int ms = (clock() - start) / (CLOCKS_PER_SEC / 1000.0) + 0.5;
  // Size calculation does not work if opt >1 or if compiler or linker
  // otherwise reorders functions in the binary.
  int codeSz = (char*)main - (char*)countPrimes;
  printf("%d primes found in %d ms\n", res, ms);
  printf("%d bytes of code in countPrimes()\n", codeSz);
  return 0;
}
