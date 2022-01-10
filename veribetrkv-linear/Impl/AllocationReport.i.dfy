// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "../lib/Lang/NativeTypes.s.dfy"
include "NodeImpl.i.dfy"

module {:extern} AllocationReport {
  import opened NativeTypes
  import NodeImpl
  method {:extern "AllocationReport_Compile", "start"} start()
  method {:extern "AllocationReport_Compile", "sampleNode"} sampleNode(ref: uint64, node: NodeImpl.Node)
  method {:extern "AllocationReport_Compile", "stop"} stop()
}
