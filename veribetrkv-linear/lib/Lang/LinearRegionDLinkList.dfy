// Verified with Linear Dafny and Z3 version 4.8.5
// Dafny options: /restartProver /noNLarith

//////////////////////////// Region Library Interface //////////////////////////////

// Trusted Library for regions with ML-style ref cells
// Note: in Dafny-to-C++ compilation, type A is inlined into implementation of RefCell<A>,
// avoiding extra indirection in doubly linked list example.
// (More specifically, RefCell<A> is just a C++ shared_ptr<A>.)

module {:extern "LinearRegion"} LinearRegion {
  type {:extern "predefined"} Region
}

module {:extern "LinearRegionId_s"} LinearRegionId {
  type {:extern "predefined"} RegionId
}

module {:extern "LinearRegionRefCell_s"} LinearRegionRefCell {
  type {:extern "predefined"} RefCell(==)<A>
}

module {:extern "LinearRegionLoc_s"} LinearRegionLoc {
  type {:extern "predefined"} Loc
}

module {:extern "LinearRegion_s"} LinearRegion_s {
  import LinearRegion
  import LinearRegionId
  import LinearRegionRefCell
  import LinearRegionLoc

  // Regions with ML-style ref cells

  type Region = LinearRegion.Region
  type RegionId = LinearRegionId.RegionId
  type RefCell(==)<A> = LinearRegionRefCell.RefCell<A>
  type Loc = LinearRegionLoc.Loc

  function {:axiom} Id(g: Region): RegionId
  function {:axiom} Allocated(g: Region): set<Loc>
  function {:axiom} RefLoc<A>(r: RefCell<A>): Loc
  function {:axiom} LocRef<A(00)>(l: Loc): RefCell<A>

  predicate {:axiom} ValidRef(loc: Loc, id: RegionId, is_linear: bool)

  function {:axiom} Get<A>(g: Region, r: RefCell<A>): A

  function {:axiom} Modifies(locs: set<Loc>, g1: Region, g2: Region): (b: bool)
    ensures b ==> Id(g1) == Id(g2)
    ensures b ==> Allocated(g1) <= Allocated(g2)

  function method {:extern "LinearRegion_s", "Read"} Read<A>(shared g: Region, r: RefCell<A>): (a: A)
    requires ValidRef(RefLoc(r), Id(g), false)
    ensures Get(g, r) == a

  function method {:extern "LinearRegion_s", "Borrow"} Borrow<A>(shared g: Region, r: RefCell<A>): (shared a: A)
    requires ValidRef(RefLoc(r), Id(g), true)
    ensures Get(g, r) == a

  method {:extern "LinearRegion_s", "Write"} Write<A>(linear inout g: Region, r: RefCell<A>, a: A)
    requires ValidRef(RefLoc(r), Id(old_g), false)
    ensures Get(g, r) == a
    ensures Modifies({RefLoc(r)}, old_g, g)

  method {:extern "LinearRegion_s", "Swap"} Swap<A>(linear inout g: Region, r: RefCell<A>, linear inout a: A)
    requires ValidRef(RefLoc(r), Id(old_g), true)
    ensures Get(old_g, r) == a
    ensures Get(g, r) == old_a
    ensures Modifies({RefLoc(r)}, old_g, g)

  method {:extern "LinearRegion_s", "Alloc"} Alloc<A>(linear inout g: Region, a: A) returns(r: RefCell<A>)
    ensures ValidRef(RefLoc(r), Id(g), false)
    ensures Get(g, r) == a
    ensures Modifies({}, old_g, g)
    ensures RefLoc(r) !in Allocated(old_g)
    ensures RefLoc(r) in Allocated(g)

  method {:extern "LinearRegion_s", "AllocLinear"} AllocLinear<A>(linear inout g: Region, linear a: A) returns(r: RefCell<A>)
    ensures ValidRef(RefLoc(r), Id(g), true)
    ensures Get(g, r) == a
    ensures Modifies({}, old_g, g)
    ensures RefLoc(r) !in Allocated(old_g)
    ensures RefLoc(r) in Allocated(g)

  method {:extern "LinearRegion_s", "NewRegion"} NewRegion() returns(linear g: Region)

  // Note: freeing the region eliminates the permission to alloc/read/write/swap,
  // but it doesn't immediately free the objects in the region,
  // so for the Dafny-to-C++ implementation that uses reference counting,
  // you still need to break reference counting cycles manually
  method {:extern "LinearRegion_s", "FreeRegion"} FreeRegion(linear g: Region)

  lemma {:axiom} LemmaModifies()
    ensures forall g :: Modifies({}, g, g)
    ensures forall locs1, locs2, g1, g2 ::
      Modifies(locs1, g1, g2) && locs1 <= locs2 ==>
      Modifies(locs2, g1, g2)
    ensures
      forall locs1, locs2, locs3, g1, g2, g3 ::
        Modifies(locs1, g1, g2) && Modifies(locs2, g2, g3) && locs3 == locs1 + locs2 ==>
        Modifies(locs3, g1, g3)

  lemma {:axiom} LemmaUnmodified<A(00)>()
    ensures forall r:RefCell<A> {:trigger RefLoc(r)} :: LocRef(RefLoc(r)) == r
    ensures forall l:Loc {:trigger RefLoc<A>(LocRef(l))} :: RefLoc<A>(LocRef(l)) == l
    ensures
      forall r:RefCell<A>, locs, g1, g2 ::
        Modifies(locs, g1, g2) && RefLoc(r) !in locs ==>
        Get(g1, r) == Get(g2, r)
}

//////////////////////////// Linear Doubly Linked List //////////////////////////////

module LinearDLinkList {
  import opened LinearRegion_s
  export
    // List of abstract types, functions, and methods provided by the module
    // (all implementations hidden)
    provides NodePtr, List, ListInv, ValidPtr, Data
    provides NewList, FreeList
    provides IsEmpty, IsFirst, IsLast
    provides GetValue, GetFirst, GetLast, GetNext, GetPrev
    provides Remove, InsertLast, InsertBefore

  // Verified doubly linked list

  // Note: the compilation of datatypes to C++ uses a flat memory representation based on std::variant
  datatype Option<A> = None | Some(a: A)
  datatype Node<A> = Nil | Cons(data: Option<A>, next: RefCell<Node<A>>, prev: RefCell<Node<A>>)
  type NodePtr<A> = RefCell<Node<A>>

  linear datatype List<A> = List(
    linear g: Region,
    sentinel: NodePtr<A>,
    ghost data: seq<A>,
    ghost refs: seq<NodePtr<A>>)

  predicate ListFieldInv<A>(g: Region, sentinel: NodePtr<A>, data: seq<A>, refs: seq<NodePtr<A>>)
  {
    && |refs| == |data| + 1
    && sentinel == refs[0]
    && (forall i :: 0 <= i < |refs| ==> RefLoc(refs[i]) in Allocated(g))
    && (forall i :: 0 <= i < |refs| ==> ValidRef(RefLoc(refs[i]), Id(g), false))
    && (forall i, j :: 0 <= i < j < |refs| ==> refs[i] != refs[j])
    && (forall i {:trigger Get(g, refs[i])} :: 0 <= i < |refs| ==> Get(g, refs[i]).Cons?)
    && Get(g, refs[0]).prev == refs[|data|]
    && Get(g, refs[|data|]).next == refs[0]
    && (forall i {:trigger Get(g, refs[i])} :: 1 <= i < |refs| ==> Get(g, refs[i]).data == Some(data[i - 1]))
    && (forall i {:trigger Get(g, refs[i])} :: 0 <= i < |refs| - 1 ==> Get(g, refs[i]).next == refs[i + 1])
    && (forall i {:trigger Get(g, refs[i])} :: 1 <= i < |refs| ==> Get(g, refs[i]).prev == refs[i - 1])
  }

  predicate ListInv<A>(list: List<A>)
  {
    ListFieldInv(list.g, list.sentinel, list.data, list.refs)
  }

  predicate ValidPtr<A>(list: List<A>, ptr: NodePtr<A>, index: int)
  {
    && 0 < index + 1 < |list.refs|
    && list.refs[index + 1] == ptr
  }

  function Data<A>(list: List<A>): seq<A>
  {
    list.data
  }

  method NewList<A>() returns(linear list: List<A>)
    ensures ListInv(list)
    ensures Data(list) == []
  {
    linear var g := NewRegion();
    var sentinel := Alloc(inout g, Nil);
    Write(inout g, sentinel, Cons(None, sentinel, sentinel));
    list := List(g, sentinel, [], [sentinel]);
  }

  method FreeList<A>(linear list: List<A>)
    requires ListInv(list)
    requires |Data(list)| == 0
  {
    linear var List(g, sentinel, data, refs) := list;
    Write(inout g, sentinel, Nil); // break cycle
    FreeRegion(g);
  }

  function method IsEmpty<A>(shared list: List): (b: bool)
    requires ListInv(list)
    ensures b <==> |Data(list)| == 0
  {
    Read(list.g, list.sentinel).next == list.sentinel
  }

  function method IsFirst<A>(shared list: List, ptr: NodePtr<A>, ghost index: int): (b: bool)
    requires ListInv(list)
    requires 0 <= index < |Data(list)|
    requires ValidPtr(list, ptr, index)
    ensures b <==> index == 0
  {
    Read(list.g, ptr).prev == list.sentinel
  }

  function method IsLast<A>(shared list: List, ptr: NodePtr<A>, ghost index: int): (b: bool)
    requires ListInv(list)
    requires 0 <= index < |Data(list)|
    requires ValidPtr(list, ptr, index)
    ensures b <==> index == |Data(list)| - 1
  {
    Read(list.g, ptr).next == list.sentinel
  }

  function method GetValue<A>(shared list: List, ptr: NodePtr<A>, ghost index: int): (a: A)
    requires ListInv(list)
    requires 0 <= index < |Data(list)|
    requires ValidPtr(list, ptr, index)
    ensures a == Data(list)[index]
  {
    Read(list.g, ptr).data.a
  }

  function method GetFirst<A>(shared list: List): (ptr: NodePtr<A>)
    requires ListInv(list)
    requires |Data(list)| > 0
    ensures ValidPtr(list, ptr, 0)
  {
    Read(list.g, list.sentinel).next
  }

  function method GetLast<A>(shared list: List): (ptr: NodePtr<A>)
    requires ListInv(list)
    requires |Data(list)| > 0
    ensures ValidPtr(list, ptr, |Data(list)| - 1)
  {
    Read(list.g, list.sentinel).prev
  }

  function method GetNext<A>(shared list: List, ptr: NodePtr<A>, ghost index: int): (next: NodePtr<A>)
    requires ListInv(list)
    requires 0 <= index < |Data(list)| - 1
    requires ValidPtr(list, ptr, index)
    ensures ValidPtr(list, next, index + 1)
  {
    Read(list.g, ptr).next
  }

  function method GetPrev<A>(shared list: List, ptr: NodePtr<A>, ghost index: int): (next: NodePtr<A>)
    requires ListInv(list)
    requires 1 <= index < |Data(list)|
    requires ValidPtr(list, ptr, index)
    ensures ValidPtr(list, next, index - 1)
  {
    Read(list.g, ptr).prev
  }

  function{:opaque} RemoveMiddle<A>(s: seq<A>, index: int): (s': seq<A>)
    requires 0 <= index < |s|
    ensures |s'| == |s| - 1
    ensures forall i :: 0 <= i < index ==> s'[i] == s[i]
    ensures forall i :: index <= i < |s'| ==> s'[i] == s[i + 1]
  {
    s[..index] + s[index + 1..]
  }

  function{:opaque} InsertMiddle<A>(s: seq<A>, a: A, index: int): (s': seq<A>)
    requires 0 <= index < |s|
    ensures |s'| == |s| + 1
    ensures s'[index] == a
    ensures forall i :: 0 <= i < index ==> s'[i] == s[i]
    ensures forall i :: index + 1 <= i < |s'| ==> s'[i] == s[i - 1]
  {
    s[..index] + [a] + s[index..]
  }

  method Remove<A>(linear inout list: List, ptr: NodePtr<A>, ghost index: int)
    requires ListInv(old_list)
    requires 0 <= index < |Data(old_list)|
    requires ValidPtr(old_list, ptr, index)
    ensures ListInv(list)
    ensures Data(list) == Data(old_list)[..index] + Data(old_list)[index + 1 ..]
    ensures forall i, p :: 0 <= i < index && ValidPtr(old_list, p, i) ==> ValidPtr(list, p, i)
    ensures forall i, p :: index < i < |Data(old_list)| && ValidPtr(old_list, p, i) ==> ValidPtr(list, p, i - 1)
  {
    LemmaModifies();
    LemmaUnmodified<Node<A>>();

    linear var List(g, sentinel, data, refs) := list;
    var node := Read(g, ptr);

    var next := Read(g, node.next);
    Write(inout g, node.next, next.(prev := node.prev));

    var prev := Read(g, node.prev);
    Write(inout g, node.prev, prev.(next := node.next));

    // break cycle
    Write(inout g, ptr, Nil);

    data := RemoveMiddle(data, index);
    refs := RemoveMiddle(refs, index + 1);
    list := List(g, sentinel, data, refs);
  }

  method InsertLast<A>(linear inout list: List, a: A) returns(ptr: NodePtr<A>)
    requires ListInv(old_list)
    ensures ListInv(list)
    ensures Data(list) == Data(old_list) + [a]
    ensures ValidPtr(list, ptr, |Data(old_list)|)
    ensures forall i, p :: 0 <= i < |Data(old_list)| && ValidPtr(old_list, p, i) ==> ValidPtr(list, p, i)
  {
    LemmaModifies();
    LemmaUnmodified<Node<A>>();

    linear var List(g, sentinel, data, refs) := list;
    var next := Read(g, sentinel);

    ptr := Alloc(inout g, Cons(Some(a), sentinel, next.prev));
    Write(inout g, sentinel, next.(prev := ptr));

    var prev := Read(g, next.prev);
    Write(inout g, next.prev, prev.(next := ptr));

    data := data + [a];
    refs := refs + [ptr];
    list := List(g, sentinel, data, refs);
  }

  method InsertBefore<A>(linear inout list: List, ptr: NodePtr<A>, a: A, ghost index: int)
    returns(ptr': NodePtr<A>)
    requires ListInv(old_list)
    requires 0 <= index < |Data(old_list)|
    requires ValidPtr(old_list, ptr, index)
    ensures ListInv(list)
    ensures Data(list) == Data(old_list)[..index] + [a] + Data(old_list)[index..]
    ensures ValidPtr(list, ptr', index)
    ensures forall i, p :: 0 <= i < index && ValidPtr(old_list, p, i) ==> ValidPtr(list, p, i)
    ensures forall i, p :: index <= i < |Data(old_list)| && ValidPtr(old_list, p, i) ==> ValidPtr(list, p, i + 1)
  {
    LemmaModifies();
    LemmaUnmodified<Node<A>>();

    linear var List(g, sentinel, data, refs) := list;
    var next := Read(g, ptr);

    ptr' := Alloc(inout g, Cons(Some(a), ptr, next.prev));
    Write(inout g, ptr, next.(prev := ptr'));

    var prev := Read(g, next.prev);
    Write(inout g, next.prev, prev.(next := ptr'));

    data := InsertMiddle(data, a, index);
    refs := InsertMiddle(refs, ptr', index + 1);
    list := List(g, sentinel, data, refs);
  }
}

module Test {
  import opened LinearDLinkList

  method TestList() {
    linear var list := NewList();
    var ptr1 := InsertLast(inout list, 10);
    var ptr2 := InsertLast(inout list, 20);
    var ptr3 := InsertLast(inout list, 30);

    Remove(inout list, ptr2, 1);
    assert Data(list) == [10, 30];

    var d3 := GetValue(list, ptr3, 1);
    assert d3 == 30;

    Remove(inout list, ptr1, 0);
    Remove(inout list, ptr3, 0);
    FreeList(list);
  }
}