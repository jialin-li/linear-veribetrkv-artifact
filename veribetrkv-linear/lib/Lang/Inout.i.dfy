// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

module Inout {
    method Replace<V>(linear inout v: V, linear newv: V)
    returns (linear replaced: V)
    ensures v == newv
    ensures replaced == old_v
    {
      linear var tmp := newv;
      replaced := v;
      v := tmp;
    }
}
