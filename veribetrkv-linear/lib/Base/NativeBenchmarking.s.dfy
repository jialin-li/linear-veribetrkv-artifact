// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

// Some utilities for benchmarking via explicit instrumentation.

module {:extern} NativeBenchmarking {
  method {:extern "NativeBenchmarking_Compile", "start"} start(name: string)
  method {:extern "NativeBenchmarking_Compile", "end"} end(name: string)
}
