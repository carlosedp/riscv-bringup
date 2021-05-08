# Unmatched Info

NVME Sensor exposed thru Kernel (enabled CONFIG_NVME_HWMON):

```sh
❯ sensors
nvme-pci-0600
Adapter: PCI adapter
Composite:    +37.9°C  (low  = -273.1°C, high = +82.8°C)
                       (crit = +84.8°C)

tmp451-i2c-0-4c
Adapter: i2c-ocores
temp1:        +40.1°C  (low  =  +0.0°C, high = +85.0°C)
                       (crit = +85.0°C, hyst = +75.0°C)
temp2:        +46.0°C  (low  =  +0.0°C, high = +85.0°C)
                       (crit = +108.0°C, hyst = +98.0°C)
```


## Benchmark With 1Ghz

### 7zip

```sh
❯ 7z b

7-Zip 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21
p7zip Version 16.02 (locale=en_US.UTF-8,Utf16=on,HugeFiles=on,64 bits,4 CPUs LE)

LE
CPU Freq: 64000000 - - 64000000 128000000 256000000 - 1024000000 -

RAM size:   16003 MB,  # CPU hardware threads:   4
RAM usage:    882 MB,  # Benchmark threads:      4

                       Compressing  |                  Decompressing
Dict     Speed Usage    R/U Rating  |      Speed Usage    R/U Rating
         KiB/s     %   MIPS   MIPS  |      KiB/s     %   MIPS   MIPS

22:       1598   328    474   1555  |      40148   399    859   3425
23:       1570   337    475   1601  |      39430   398    857   3412
24:       1547   342    486   1664  |      38774   398    855   3404
25:       1532   351    498   1749  |      38037   399    849   3385
----------------------------------  | ------------------------------
Avr:             340    484   1642  |              398    855   3407
Tot:             369    669   2524
```


## Benchmark With 1.2Ghz

### 7zip

```sh
❯ 7z b

7-Zip 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21
p7zip Version 16.02 (locale=en_US.UTF-8,Utf16=on,HugeFiles=on,64 bits,4 CPUs LE)

LE
CPU Freq: - - - 64000000 128000000 256000000 512000000 - -

RAM size:   16003 MB,  # CPU hardware threads:   4
RAM usage:    882 MB,  # Benchmark threads:      4

                       Compressing  |                  Decompressing
Dict     Speed Usage    R/U Rating  |      Speed Usage    R/U Rating
         KiB/s     %   MIPS   MIPS  |      KiB/s     %   MIPS   MIPS

22:       1877   335    544   1826  |      47400   399   1013   4044
23:       1829   343    543   1864  |      46565   399   1009   4029
24:       1804   350    555   1940  |      45721   399   1005   4014
25:       1760   354    567   2010  |      44665   399    997   3975
----------------------------------  | ------------------------------
Avr:             346    552   1910  |              399   1006   4015
Tot:             372    779   2963
```

NVME is faster too:

```sh
❯ dd if=/dev/zero of=testimg oflag=direct bs=1M count=3000
3000+0 records in
3000+0 records out
3145728000 bytes (3.1 GB, 2.9 GiB) copied, 4.09873 s, 767 MB/s

❯ dd if=testimg of=/dev/null iflag=direct bs=1M count=3000
3000+0 records in
3000+0 records out
3145728000 bytes (3.1 GB, 2.9 GiB) copied, 2.09847 s, 1.5 GB/s
```

Hoult's Prime

```sh
Starting run
3713160 primes found in 21952 ms
236 bytes of code in countPrimes()
```

## Benchmark With 1.4Ghz

### 7zip

```sh
❯ 7z b

7-Zip 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21
p7zip Version 16.02 (locale=en_US.UTF-8,Utf16=on,HugeFiles=on,64 bits,4 CPUs LE)

LE
CPU Freq: 64000000 64000000 - 64000000 - - - - 2048000000

RAM size:   16003 MB,  # CPU hardware threads:   4
RAM usage:    882 MB,  # Benchmark threads:      4

                       Compressing  |                  Decompressing
Dict     Speed Usage    R/U Rating  |      Speed Usage    R/U Rating
         KiB/s     %   MIPS   MIPS  |      KiB/s     %   MIPS   MIPS

22:       2041   333    597   1986  |      53399   397   1148   4556
23:       2046   349    598   2085  |      52575   398   1143   4549
24:       2003   355    607   2154  |      51438   397   1137   4516
25:       1924   354    620   2197  |      50214   397   1127   4469
----------------------------------  | ------------------------------
Avr:             348    606   2106  |              397   1139   4522
Tot:             372    872   3314
```

NVME is faster too:

```sh
❯ dd if=/dev/zero of=testimg oflag=direct bs=1M count=3000
3000+0 records in
3000+0 records out
3145728000 bytes (3.1 GB, 2.9 GiB) copied, 3.78181 s, 832 MB/s

❯ dd if=testimg of=/dev/null iflag=direct bs=1M count=3000
3000+0 records in
3000+0 records out
3145728000 bytes (3.1 GB, 2.9 GiB) copied, 1.98913 s, 1.6 GB/s
```

Hoult's Prime

```sh
❯ ./primes
Starting run
3713160 primes found in 19046 ms
236 bytes of code in countPrimes()
```
