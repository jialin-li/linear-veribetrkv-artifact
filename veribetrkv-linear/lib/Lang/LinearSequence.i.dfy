// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "LinearMaybe.s.dfy"
include "LinearSequence.s.dfy"

module LinearSequence_i {
  import opened NativeTypes
  import opened LinearMaybe
  import opened LinearSequence_s
  export
    provides LinearSequence_s
    provides NativeTypes
    provides seq_alloc_init, mut_seq_set, SeqCopy, lseqs, imagine_lseq, lseq_peek, lseq_free_fun, lseq_take_fun, lseq_swap_inout, lseq_take_inout, lseq_give_inout
    provides lseq_alloc, lseq_free, lseq_swap, lseq_take, lseq_give, lseq_length_uint64, lseq_length_as_uint64, lseq_add
    provides AllocAndCopy, AllocAndMoveLseq, ImagineInverse, SeqResize, SeqResizeMut, InsertSeq, InsertLSeq, Replace1With2Lseq, Replace1With2Lseq_inout
    reveals lseq_length, lseq_full, linLast, ldroplast, lseq_has_all 
    reveals operator'cardinality?lseq, operator'in?lseq, operator'subscript?lseq

  function method seq_alloc_init<A>(length:uint64, a:A) : (linear s:seq<A>)
      ensures |s| == length as int
      ensures forall i:nat | i < |s| :: s[i] == a
  {
    seq_alloc(length, a)
  }

  function lseqs<A(00)>(l:lseq<A>):(s:seq<A>)
    ensures |s| == |lseqs_raw(l)|
  {
    var s := seq(|lseqs_raw(l)|, i requires 0 <= i < |lseqs_raw(l)| => read(lseqs_raw(l)[i]));
    axiom_lseqs_rank(l, s);
    s
  }

  function imagine_lseq<A(00)>(s:seq<A>):(l:lseq<A>)
    ensures lseqs(l) == s
    ensures forall i :: 0 <= i < |s| ==> lseq_has(l)[i]
  {
    imagine_lseq_raw(seq(|s|, i requires 0 <= i < |s| => give(s[i])))
  }

  lemma ImagineInverse<A(00)>(l:lseq<A>)
    requires forall i :: 0 <= i < |lseqs(l)| ==> lseq_has(l)[i]
    ensures imagine_lseq(lseqs(l)) == l
  {
    lemma_lseqs_extensional(imagine_lseq(lseqs(l)), l);
  }

  function linLast<A(00)>(l:lseq<A>) : A
    requires 0<|l|
  {
    lseqs(l)[|l| - 1]
  }

  function ldroplast<A(00)>(l: lseq<A>) : (l': lseq<A>)
    requires 0<|l|
    ensures |l| == |l'| + 1
    ensures forall i :: 0 <= i < |l'| ==> l'[i] == l[i]
  {
    imagine_lseq(lseqs(l)[..|l|-1])
  }

  lemma lemma_lseqs_extensional<A(00)>(l1:lseq<A>, l2:lseq<A>)
    requires |lseqs(l1)| == |lseqs(l2)|
    requires forall i :: 0 <= i < |lseqs(l1)| ==> lseqs(l1)[i] == lseqs(l2)[i] && lseq_has(l1)[i] == lseq_has(l2)[i]
    ensures l1 == l2
  {

    forall i | 0 <= i < |lseqs(l1)|
      ensures lseqs_raw(l1)[i] == lseqs_raw(l2)[i]
    {
      assert lseqs(l1)[i] == lseqs(l2)[i] && lseq_has(l1)[i] == lseq_has(l2)[i];
      axiom_extensional(lseqs_raw(l1)[i], lseqs_raw(l2)[i]);
    }
    axiom_lseqs_extensional(l1, l2);
  }

  predicate lseq_has_all<A(00)>(l:lseq<A>)
  {
    forall i :: 0<=i<|l| ==> lseq_has(l)[i]
  }

  function method lseq_length_as_uint64<A(00)>(shared s:lseq<A>) : (n:uint64)
    requires |lseqs(s)| <= 0xffff_ffff_ffff_ffff
    ensures n as nat == |lseqs(s)|
  {
    lseq_length_raw(s)
  }

  method lseq_length_uint64<A(00)>(shared s:lseq<A>) returns(n:uint64)
    ensures n as nat == |lseqs(s)|
  {
    lseq_length_bound(s);
    n := lseq_length_raw(s);
  }

  function lseq_length<A(00)>(s:lseq<A>):(n:nat)
  {
    |lseqs(s)|
  }

  function operator(| |)<A(00)>(s:lseq<A>):nat
  {
    lseq_length(s)
  }

  function{:inline true} operator([])<A(00)>(s:lseq<A>, i:nat):A
      requires i < |s|
  {
      lseqs(s)[i]
  }

  function{:inline true} operator(in)<A(00)>(s:lseq<A>, i:nat):bool
      requires i < |s|
  {
      lseq_has(s)[i]
  }

  function lseq_add<A(00)>(l:lseq<A>, r:lseq<A>): (s: lseq<A>)
  {
      imagine_lseq(lseqs(l)+lseqs(r))
  }

  function method lseq_peek<A(00)>(shared s:lseq<A>, i:uint64):(shared a:A)
      requires i as nat < |s| && i as nat in s
      ensures a == s[i as nat]
  {
      peek(lseq_share_raw(s, i))
  }

  method lseq_alloc<A(00)>(length:uint64) returns(linear s:lseq<A>)
      ensures |s| == length as nat
      ensures forall i:nat | i < length as nat :: i !in s
  {
      s := lseq_alloc_raw(length);
  }

  method lseq_free<A(00)>(linear s:lseq<A>)
      requires forall i:nat | i < |s| :: i !in s
  {
      assert forall i:nat {:trigger lseqs_raw(s)[i]} | i < |lseqs_raw(s)| :: i !in s;
      var _ := lseq_free_raw(s);
  }

  function method lseq_free_fun<A(00)>(linear s:lseq<A>) : ()
      requires forall i:nat | i < |s| :: i !in s
  {
      assert forall i:nat {:trigger lseqs_raw(s)[i]} | i < |lseqs_raw(s)| :: i !in s;
      lseq_free_raw(s)
  }

  // can be implemented as in-place swap
  method lseq_swap<A(00)>(linear s1:lseq<A>, i:uint64, linear a1:A) returns(linear s2:lseq<A>, linear a2:A)
      requires i as nat < |s1| && i as nat in s1
      ensures a2 == s1[i as nat]
      ensures lseq_has(s2) == lseq_has(s1)
      ensures lseqs(s2) == lseqs(s1)[i as nat := a1]
  {
      linear var x1:maybe<A> := give(a1);
      linear var (s2tmp, x2) := lseq_swap_raw_fun(s1, i, x1);
      s2 := s2tmp;
      a2 := unwrap(x2);
  }
  
  method lseq_swap_inout<A(00)>(linear inout s:lseq<A>, i:uint64, linear a1:A) returns(linear a2:A)
      requires i as nat < |old_s| && i as nat in old_s
      ensures a2 == old_s[i as nat]
      ensures lseq_has(s) == lseq_has(old_s)
      ensures lseqs(s) == lseqs(old_s)[i as nat := a1]
  {
    s, a2 := lseq_swap(s, i, a1);
  }

  method lseq_take<A(00)>(linear s1:lseq<A>, i:uint64) returns(linear s2:lseq<A>, linear a:A)
      requires i as nat < |s1| && i as nat in s1
      ensures a == s1[i as nat]
      ensures lseq_has(s2) == lseq_has(s1)[i as nat := false]
      ensures forall j:nat | j < |s1| && j != i as nat :: lseqs(s2)[j] == lseqs(s1)[j]
  {
      linear var x1:maybe<A> := empty();
      linear var (s2tmp, x2) := lseq_swap_raw_fun(s1, i, x1);
      s2 := s2tmp;
      a := unwrap(x2);
  }

  method lseq_take_inout<A(00)>(linear inout s:lseq<A>, i:uint64) returns(linear a:A)
      requires i as nat < |old_s| && i as nat in old_s
      ensures a == old_s[i as nat]
      ensures lseq_has(s) == lseq_has(old_s)[i as nat := false]
      ensures forall j:nat | j < |s| && j != i as nat :: lseqs(s)[j] == lseqs(old_s)[j]
  {
    s, a := lseq_take(s, i);
  }

  function method lseq_take_fun<A(00)>(linear s1:lseq<A>, i:uint64) : (linear p:(linear lseq<A>, linear A))
      requires i as nat < |s1| && i as nat in s1
      ensures p.1 == s1[i as nat]
      ensures lseq_has(p.0) == lseq_has(s1)[i as nat := false]
      ensures forall j:nat | j < |s1| && j != i as nat :: lseqs(p.0)[j] == lseqs(s1)[j]
  {
      linear var x1:maybe<A> := empty();
      linear var (s2tmp, x2) := lseq_swap_raw_fun(s1, i, x1);
      (linear s2tmp, linear unwrap(x2))
  }

  method lseq_give<A(00)>(linear s1:lseq<A>, i:uint64, linear a:A) returns(linear s2:lseq<A>)
      requires i as nat < |s1|
      requires i as nat !in s1
      ensures lseq_has(s2) == lseq_has(s1)[i as nat := true]
      ensures lseqs(s2) == lseqs(s1)[i as nat := a]
  {
      linear var x1:maybe<A> := give(a);
      linear var (s2tmp, x2) := lseq_swap_raw_fun(s1, i, x1);
      s2 := s2tmp;
      var _ := discard(x2);
  }

  method lseq_give_inout<A(00)>(linear inout s1:lseq<A>, i:uint64, linear a:A)
      requires i as nat < |old_s1|
      requires i as nat !in old_s1
      ensures lseq_has(s1) == lseq_has(old_s1)[i as nat := true]
      ensures lseqs(s1) == lseqs(old_s1)[i as nat := a]
  {
    s1 := lseq_give(s1, i, a);
  }


  predicate lseq_full<A(00)>(s: lseq<A>)
  {
      && (forall i | 0 <= i < |s| :: i in s)
  }

  method SeqCopy<A>(shared source: seq<A>, linear inout dest: seq<A>, start: uint64, end: uint64, dest_start: uint64)
  requires 0 <= start as nat <= end as nat <= |source|
  requires 0 <= dest_start as nat <= dest_start as nat + (end-start) as nat <= |old_dest|
  requires |old_dest| < Uint64UpperBound()
  ensures |dest| == |old_dest|
  ensures source[start..end] == dest[dest_start as nat .. dest_start as nat + (end-start) as nat]
  ensures forall i | 0 <= i < dest_start :: dest[i] == old_dest[i]
  ensures forall i | dest_start as nat + (end-start) as nat <= i < |dest| :: dest[i] == old_dest[i]
  {
    var i := 0;
    var len := end - start;

    while i < len
      invariant 0 <= i <= len
      invariant |dest| == |old_dest|
      invariant (i + dest_start) as nat <= (len + dest_start) as nat <= |dest|
      invariant forall j :: 0 <= j < i ==> dest[j+dest_start] == source[j+start];
      invariant forall j | 0 <= j < dest_start :: dest[j] == old_dest[j]
      invariant forall j :: (i+dest_start) as nat <= j < |dest| ==> dest[j] == old_dest[j]
    {
      mut_seq_set(inout dest, i+dest_start, seq_get(source, i+start));
      i := i + 1;
    }

    assert forall j :: 0<=j<len ==> 
      dest[j+dest_start] == dest[dest_start..][j] 
      == dest[dest_start as nat .. dest_start as nat + (end-start) as nat][j];
  }

  // TODO(robj): "probably not as fast as a memcpy"
  method AllocAndCopy<A>(shared source: seq<A>, from: uint64, to: uint64)
    returns (linear dest: seq<A>)
    requires 0 <= from as nat <= to as nat <= |source|;
    ensures source[from..to] == dest
  {
    if (to == from) {
      dest := seq_empty();
    } else {
      dest := seq_alloc(to - from, seq_get(source, from));
    }
    SeqCopy(source, inout dest, from, to, 0);
  }

  method AllocAndMoveLseq<A(00)>(linear source: lseq<A>, from: uint64, to: uint64)
    returns (linear looted: lseq<A>, linear loot: lseq<A>)
    requires 0 <= from as nat <= to as nat <= |source|
    requires forall j :: from as nat <= j < to as nat ==> j in source
    ensures lseq_has_all(loot)
    ensures lseqs(loot) == lseqs(source)[from..to]
    ensures |looted| == |source|
    ensures forall j :: 0<=j<|source| && !(from as nat <= j < to as nat) ==> looted[j] == old(source)[j]
    ensures forall j :: 0<=j<|source|
      ==> lseq_has(looted)[j] == if from as nat <= j < to as nat then false else lseq_has(source)[j]
  {
    looted := source;
    ghost var count := (to - from) as nat;
    loot := lseq_alloc(to - from);
    var i:uint64 := from;
    assert to as nat <= |old(source)|;
    while i < to
      invariant from <= i <= to
      invariant |loot| == count
      invariant to as nat <= |looted|
      invariant forall j :: i <= j < to ==> lseq_has(looted)[j]
      invariant forall j :: 0 <= j < to-from ==> lseq_has(loot)[j] == (j < i-from)
      invariant lseqs(loot)[..i-from] == lseqs(old(source))[from..i]
      invariant |looted| == |old(source)|
      invariant forall j :: 0<=j<|source| && !(from as nat <= j < i as nat) ==> looted[j] == old(source)[j]
      invariant forall j :: 0<=j<|looted|
      ==> lseq_has(looted)[j] == if from as nat <= j < i as nat then false else lseq_has(old(source))[j]
    {
      assert lseqs(loot)[..i-from] == lseqs(old(source))[from..i]; // seems like the assertion below needs this
      linear var elt:A;
      looted, elt := lseq_take(looted, i);
      loot := lseq_give(loot, i-from, elt);
      i := i + 1;
      assert lseqs(loot)[..i-from] == lseqs(old(source))[from..i]; // observe
    }
  }

  method SeqResize<A>(linear s: seq<A>, newlen: uint64, a: A) returns (linear s2: seq<A>)
    ensures |s2| == newlen as nat
    ensures forall j :: 0 <= j < newlen as nat ==> s2[j] == (if j < |s| then s[j] else a)
  {
    shared_seq_length_bound(s);
    var i:uint64 := seq_length(s);
    s2 := TrustedRuntimeSeqResize(s, newlen);
    while (i < newlen)
      invariant |s2| == newlen as nat
      invariant |s| <= |s2| ==> |s| <= i as nat <= |s2|
      invariant forall j :: 0 <= j < i as nat && j < |s2| ==> s2[j] == (if j < |s| then s[j] else a)
    {
      s2 := seq_set(s2, i, a);
      i := i + 1;
    }
  }

  // method {:extern "LinearExtern", "TrustedRuntimeSeqResizeMut"} TrustedRuntimeSeqResizeMut<A(00)>(linear inout s: seq<A>, newlen: uint64)
  //   ensures |s| == newlen as nat
  //   ensures forall j :: 0 <= j < newlen as nat && j < |old_s| ==> s[j] == old_s[j]

  method SeqResizeMut<A>(linear inout s: seq<A>, newlen: uint64, a: A)
    ensures |s| == newlen as nat
    ensures forall j :: 0 <= j < newlen as nat ==> s[j] == (if j < |old_s| then old_s[j] else a)
  {
    shared_seq_length_bound(s);
    var i:uint64 := seq_length(s);
    // TrustedRuntimeSeqResizeMut(inout s, newlen);
    s := TrustedRuntimeSeqResize(s, newlen);

    while (i < newlen)
      invariant |s| == newlen as nat
      invariant |old_s| <= |s| ==> |old_s| <= i as nat <= |s|
      invariant forall j :: 0 <= j < i as nat && j < |s| ==> s[j] == (if j < |old_s| then old_s[j] else a)
    {
      mut_seq_set(inout s, i, a);
      i := i + 1;
    }
  }

  method InsertSeq<A>(linear s: seq<A>, a: A, pos: uint64) returns (linear s2: seq<A>)
    requires |s| < Uint64UpperBound() - 1;
    requires 0 <= pos as int <= |s|;
    ensures s2 == s[..pos] + [a] + s[pos..];
  {
    var len := seq_length(s);
    var newlen: uint64 := len as uint64 + 1;
    s2 := TrustedRuntimeSeqResize(s, newlen);

    var i:uint64 := newlen - 1;
    while i > pos
      invariant i >= pos
      invariant |s2| == newlen as nat;
      invariant forall j :: 0 <= j <= i as nat - 1 ==> s2[j] == old(s)[j]
      invariant forall j :: i as nat +1 <= j < |s2| ==> s2[j] == old(s)[j-1]
    {
      var prevElt := seq_get(s2, i-1);
      s2 := seq_set(s2, i, prevElt);
      i := i - 1;
    }
    s2 := seq_set(s2, pos, a);
  }

  method InsertLSeq<A(00)>(linear s: lseq<A>, linear a: A, pos: uint64) returns (linear s2: lseq<A>)
    requires lseq_has_all(s)  // robj points out that you only really need to has all the elements >=pos
    requires |s| < Uint64UpperBound() - 1;
    requires 0 <= pos as int <= |s|;
    ensures lseq_has_all(s2)
    ensures lseqs(s2) == lseqs(s)[..pos] + [a] + lseqs(s)[pos..];
  {
    var len: uint64 := lseq_length_raw(s);
    var newlen: uint64 := len + 1;

    s2 := TrustedRuntimeLSeqResize(s, newlen);

    var i:uint64 := newlen - 1;
    while i > pos
      invariant i >= pos
      invariant |s2| == newlen as nat;
      // i is where we're writing next; it's the only hole in s2:
      invariant forall j :: 0 <= j < |s2| ==> lseq_has(s2)[j] == (j != i as nat)
      // Everything before i has its original value
      invariant forall j :: 0 <= j <= i as nat - 1 ==> s2[j] == old(s)[j]
      // Everything after i has the value of its original -1 neighbor
      invariant forall j :: i as nat +1 <= j < |s2| ==> s2[j] == old(s)[j-1]
    {
      linear var prevElt;
      s2, prevElt := lseq_take(s2, i-1);
      s2 := lseq_give(s2, i, prevElt);
      i := i - 1;
    }
    s2 := lseq_give(s2, pos, a);
  }

  method Replace1With2Lseq<A(00)>(linear s: lseq<A>, linear l: A, linear r: A, pos: uint64) returns (linear s2: lseq<A>, linear replaced: A)
    requires lseq_has_all(s)
    requires |s| < Uint64UpperBound() - 1;
    requires 0 <= pos as int < |s|;
    ensures lseq_has_all(s2)
    ensures lseqs(s2) == lseqs(s)[..pos] + [l] + [r] + lseqs(s)[pos+1..];
    ensures replaced == s[pos as nat]
  {
    s2, replaced := lseq_swap(s, pos, l);
    s2 := InsertLSeq(s2, r, pos+1);
  }

  method Replace1With2Lseq_inout<A(00)>(linear inout s: lseq<A>, linear l: A, linear r: A, pos: uint64) returns (linear replaced: A)
    requires lseq_has_all(old_s)
    requires |old_s| < Uint64UpperBound() - 1;
    requires 0 <= pos as int < |old_s|;
    ensures lseq_has_all(s)
    ensures lseqs(s) == lseqs(old_s)[..pos] + [l] + [r] + lseqs(old_s)[pos+1..];
    ensures replaced == old_s[pos as nat]
  {
    replaced := lseq_swap_inout(inout s, pos, l);
    s := InsertLSeq(s, r, pos+1);
  }

  method mut_seq_set<A>(linear inout s:seq<A>, i:uint64, a:A)
  requires i as nat < |old_s|
  ensures s == old_s[i as nat := a]
  {
    s := seq_set(s, i, a);
  }

  //     requires i as nat < |old_s|
  //     ensures s == old_s[i as nat := a]

} // module LinearSequence_i
