// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "CompositeView_Refines_TSJMap.i.dfy"
include "../MapSpec/TSJMap_Refines_ThreeStateVersionedMap.i.dfy"

//
// Composes the two refinements:
//
//   CompositeView -> TSJMap
//   TSJMap -> ThreeStateVersioned Map
//
// To yield
//
//   CompositeView -> ThreeStateVersioned Map
//

module CompositeView_Refines_ThreeStateVersionedMap {
  import A = CompositeView
  import B = TSJMap
  import C = ThreeStateVersionedMap

  import Ref_A = CompositeView_Refines_TSJMap
  import Ref_B = TSJMap_Refines_ThreeStateVersionedMap
  
  import UI

  function I(s: A.Variables) : C.Variables
  requires A.Inv(s)
  {
    Ref_B.I(
      Ref_A.I(s)
    )
  }

  lemma RefinesInit(s: A.Variables)
    requires A.Init(s)
    ensures A.Inv(s)
    ensures C.Init(I(s))
  {
    Ref_A.RefinesInit(s);
    Ref_B.RefinesInit(
      Ref_A.I(s));
  }

  lemma RefinesNext(s: A.Variables, s': A.Variables, uiop: UI.Op)
    requires A.Inv(s)
    requires A.Next(s, s', uiop)
    ensures A.Inv(s')
    ensures C.Next(I(s), I(s'), uiop)
  {
    Ref_A.RefinesNext(s, s', uiop);
    Ref_B.RefinesNext(
      Ref_A.I(s),
      Ref_A.I(s'),
      uiop);
  }
}
