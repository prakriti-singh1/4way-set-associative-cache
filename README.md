# 4-Way Set Associative Cache

> SystemVerilog implementation of a 4-way set associative cache controller with LRU replacement, write-back policy, and latency-aware main memory model.

## Overview

This project implements a **4-way set associative cache controller** in **SystemVerilog** to reduce average memory access latency by exploiting temporal and spatial locality.

The cache controller communicates with a simulated main memory and handles cache hits, misses, block allocation, and dirty block write-back using a finite state machine (FSM).

The project also includes a self-checking verification testbench to validate cache functionality and memory consistency.

---

## Features

* 4-Way Set Associative Cache Organization
* Least Recently Used (LRU) Replacement Policy
* Write-Back Cache Policy
* Write-Allocate on Write Miss
* Valid Bit Management
* Dirty Bit Management
* Automatic Block Allocation
* Dirty Block Eviction and Write-Back
* Latency-Aware Main Memory Model
* FSM-Based Cache Controller
* Self-Checking Verification Testbench

---

## Cache Configuration

| Parameter          | Value          |
| ------------------ | -------------- |
| Number of Sets     | 4              |
| Associativity      | 4-Way          |
| Address Width      | 32-bit         |
| Data Width         | 32-bit         |
| Replacement Policy | LRU            |
| Write Policy       | Write-Back     |
| Allocation Policy  | Write Allocate |

---

## Address Format

The 32-bit CPU address is divided into:

| Field        | Bits   |
| ------------ | ------ |
| Tag          | [31:4] |
| Set Index    | [3:2]  |
| Block Offset | [1:0]  |

```
------------------------------------------------
|               Tag            | Set | Offset |
------------------------------------------------
|            28 bits           |2bit | 2 bits |
------------------------------------------------
```

---

## Cache Operation

### Cache Hit

If a valid cache line with a matching tag exists in the selected set:

* Read requests return data directly from cache.
* Write requests update cache contents.
* Dirty bit is updated on writes.
* LRU ordering is refreshed.

### Cache Miss

If the requested block is not present:

1. Search for an invalid cache line.
2. If all ways are occupied, select a victim using LRU.
3. If the victim block is dirty:

   * Write it back to main memory.
4. Fetch the requested block from memory.
5. Install the new block into cache.
6. Resume CPU execution.

---

## LRU Replacement Policy

The cache uses the **Least Recently Used (LRU)** replacement algorithm.

Each cache line stores an LRU rank:

* `0` → Most Recently Used
* `3` → Least Recently Used

When replacement is required, the cache evicts the line with the highest LRU rank.

---

## Cache Controller FSM

The cache controller operates using three states:

### IDLE

Handles CPU requests and performs cache lookup.

### WRITE_BACK

Writes dirty victim blocks back to main memory before replacement.

### ALLOCATE

Fetches requested data from memory and installs it into cache.

---

## Main Memory Model

A behavioral main memory model is included for simulation.

### Memory Configuration

| Parameter     | Value     |
| ------------- | --------- |
| Memory Size   | 256 Words |
| Data Width    | 32-bit    |
| Read Latency  | 2 Cycles  |
| Write Latency | 2 Cycles  |

## Verification Results

Example output from the self-checking testbench:

```text
PASS READ  addr=0 expected=100 got=100
PASS READ  addr=0 expected=100 got=100
WRITE      addr=0 data=999
PASS READ  addr=0 expected=999 got=999
PASS WRITEBACK memory[0]=999

=========================================
Verification Summary
=========================================
PASS COUNT  = 12
FAIL COUNT  = 0
FINAL RESULT: TEST PASSED
=========================================
```

### Memory Initialization

Memory is initialized during reset as:

```
memory[0]   = 100
memory[1]   = 101
memory[2]   = 102
...
memory[255] = 355
```

This deterministic initialization simplifies debugging and verification.

---

## Verification

A self-checking SystemVerilog testbench validates cache functionality.

### Verified Scenarios

* Read Miss
* Read Hit
* Write Hit
* Cache Allocation
* LRU Update
* Cache Replacement
* Dirty Block Write-Back
* Main Memory Consistency

### Example Output

```
PASS READ  addr=0 expected=100 got=100
PASS READ  addr=0 expected=100 got=100
WRITE addr=0 data=999
PASS READ  addr=0 expected=999 got=999
PASS WRITEBACK memory[0]=999

=========================================
Verification Summary
=========================================
PASS COUNT = 12
FAIL COUNT = 0
FINAL RESULT : TEST PASSED
=========================================
```

---

## Project Structure

```
4way-set-associative-cache/
│
├── cache_controller.sv
├── main_memory.sv
├── tb_cache_controller.sv
├── README.md
└── waveforms/
```

---

## Concepts Demonstrated

* Cache Memory Architecture
* Set Associative Mapping
* LRU Replacement Algorithms
* Memory Hierarchy Design
* RTL Design in SystemVerilog
* FSM-Based Control Logic
* Hardware Verification Methodologies

---

## Future Improvements

- Support for multi-word cache blocks to improve spatial locality.
- Parameterization of cache size, associativity, and block size.
- Cache performance counters including hit rate and miss rate statistics.
- Multi-level cache hierarchy support (L1/L2 cache).
- Integration with standard bus protocols such as AXI or AHB.
- Replacement of true LRU with hardware-efficient pseudo-LRU schemes for larger associativities.
- Extension towards cache coherence support for multicore systems.

---

## Author

Developed using SystemVerilog as an RTL implementation of a set associative cache memory subsystem for computer architecture and digital design applications.
