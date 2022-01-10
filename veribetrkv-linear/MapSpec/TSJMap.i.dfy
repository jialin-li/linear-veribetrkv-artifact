// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "../MapSpec/TSJ.i.dfy"
include "../MapSpec/MapSpec.s.dfy"

module TSJMap refines TSJ {
  import SM = MapSpec
}
