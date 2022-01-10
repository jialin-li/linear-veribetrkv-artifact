// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "../Lang/NativeTypes.s.dfy"

module {:extern} MallocAccounting {
  import opened NativeTypes
  method {:extern "MallocAccounting_Compile", "set_amass_mode"} set_amass_mode(amass_mode:bool)
}
