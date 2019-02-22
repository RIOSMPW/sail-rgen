(*Require Import Sail_impl_base*)
Require Import Sail2_values.
Require Import Sail2_prompt_monad.
Require Export ZArith.Zwf.
Require Import List.
Import ListNotations.
(*

val iter_aux : forall 'rv 'a 'e. integer -> (integer -> 'a -> monad 'rv unit 'e) -> list 'a -> monad 'rv unit 'e
let rec iter_aux i f xs = match xs with
  | x :: xs -> f i x >> iter_aux (i + 1) f xs
  | [] -> return ()
  end

declare {isabelle} termination_argument iter_aux = automatic

val iteri : forall 'rv 'a 'e. (integer -> 'a -> monad 'rv unit 'e) -> list 'a -> monad 'rv unit 'e
let iteri f xs = iter_aux 0 f xs

val iter : forall 'rv 'a 'e. ('a -> monad 'rv unit 'e) -> list 'a -> monad 'rv unit 'e
let iter f xs = iteri (fun _ x -> f x) xs

val foreachM : forall 'a 'rv 'vars 'e.
  list 'a -> 'vars -> ('a -> 'vars -> monad 'rv 'vars 'e) -> monad 'rv 'vars 'e*)
Fixpoint foreachM {a rv Vars e} (l : list a) (vars : Vars) (body : a -> Vars -> monad rv Vars e) : monad rv Vars e :=
match l with
| [] => returnm vars
| (x :: xs) =>
  body x vars >>= fun vars =>
  foreachM xs vars body
end.

Fixpoint foreach_ZM_up' {rv e Vars} from to step off n `{ArithFact (0 < step)} `{ArithFact (0 <= off)} (vars : Vars) (body : forall (z : Z) `(ArithFact (from <= z <= to)), Vars -> monad rv Vars e) {struct n} : monad rv Vars e :=
  if sumbool_of_bool (from + off <=? to) then
    match n with
    | O => returnm vars
    | S n => body (from + off) _ vars >>= fun vars => foreach_ZM_up' from to step (off + step) n vars body
    end
  else returnm vars.

Fixpoint foreach_ZM_down' {rv e Vars} from to step off n `{ArithFact (0 < step)} `{ArithFact (off <= 0)} (vars : Vars) (body : forall (z : Z) `(ArithFact (to <= z <= from)), Vars -> monad rv Vars e) {struct n} : monad rv Vars e :=
  if sumbool_of_bool (to <=? from + off) then
    match n with
    | O => returnm vars
    | S n => body (from + off) _ vars >>= fun vars => foreach_ZM_down' from to step (off - step) n vars body
    end
  else returnm vars.

Definition foreach_ZM_up {rv e Vars} from to step vars body `{ArithFact (0 < step)} :=
    foreach_ZM_up' (rv := rv) (e := e) (Vars := Vars) from to step 0 (S (Z.abs_nat (from - to))) vars body.
Definition foreach_ZM_down {rv e Vars} from to step vars body `{ArithFact (0 < step)} :=
    foreach_ZM_down' (rv := rv) (e := e) (Vars := Vars) from to step 0 (S (Z.abs_nat (from - to))) vars body.

(*declare {isabelle} termination_argument foreachM = automatic*)

(*val and_boolM : forall 'rv 'e. monad 'rv bool 'e -> monad 'rv bool 'e -> monad 'rv bool 'e*)
Definition and_boolM {rv E} (l : monad rv bool E) (r : monad rv bool E) : monad rv bool E :=
 l >>= (fun l => if l then r else returnm false).

Definition and_boolMP {rv E} {P Q R:bool->Prop} (x : monad rv {b:bool & P b} E) (y : monad rv {b:bool & Q b} E)
  `{H:ArithFact (forall l r, P l -> (l = true -> Q r) -> R (andb l r))}
  : monad rv {b:bool & R b} E.
refine (
  x >>= fun '(existT _ x p) => (if x return P x -> _ then
    fun p => y >>= fun '(existT _ y _) => returnm (existT _ y _)
  else fun p => returnm (existT _ false _)) p
).
* destruct H. change y with (andb true y). auto.
* destruct H. change false with (andb false false). apply fact.
  assumption.
  congruence.
Defined.

(*val or_boolM : forall 'rv 'e. monad 'rv bool 'e -> monad 'rv bool 'e -> monad 'rv bool 'e*)
Definition or_boolM {rv E} (l : monad rv bool E) (r : monad rv bool E) : monad rv bool E :=
 l >>= (fun l => if l then returnm true else r).
Definition or_boolMP {rv E} {P Q R:bool -> Prop} (l : monad rv {b : bool & P b} E) (r : monad rv {b : bool & Q b} E)
 `{ArithFact (forall l r, P l -> (l = false -> Q r) -> R (orb l r))}
 : monad rv {b : bool & R b} E.
refine (
 l >>= fun '(existT _ l p) =>
  (if l return P l -> _ then fun p => returnm (existT _ true _)
   else fun p => r >>= fun '(existT _ r _) => returnm (existT _ r _)) p
).
* destruct H. change true with (orb true true). apply fact. assumption. congruence.
* destruct H. change r with (orb false r). auto.
Defined.

Definition build_trivial_ex {rv E} {T:Type} (x:monad rv T E) : monad rv {x : T & True} E :=
  x >>= fun x => returnm (existT _ x I).

Definition and_boolBM {rv E P Q} (l : monad rv (Bool P) E) (r : monad rv (Bool Q) E) : monad rv (Bool (P /\ Q)) E.
refine (
 l >>= (fun l => if l then r >>= fun r => if r then returnm (left _) else returnm (right _) else returnm (right _))
).
all: tauto.
Defined.

Definition or_boolBM {rv E P Q} (l : monad rv (Bool P) E) (r : monad rv (Bool Q) E) : monad rv (Bool (P \/ Q)) E.
refine (
 l >>= (fun l => if l then returnm (left _) else r >>= fun r => if r then returnm (left _) else returnm (right _))
).
all: tauto.
Defined.

(*val bool_of_bitU_fail : forall 'rv 'e. bitU -> monad 'rv bool 'e*)
Definition bool_of_bitU_fail {rv E} (b : bitU) : monad rv bool E :=
match b with
  | B0 => returnm false
  | B1 => returnm true
  | BU => Fail "bool_of_bitU"
end.

(*val bool_of_bitU_oracle : forall 'rv 'e. bitU -> monad 'rv bool 'e*)
Definition bool_of_bitU_oracle {rv E} (b : bitU) : monad rv bool E :=
match b with
  | B0 => returnm false
  | B1 => returnm true
  | BU => undefined_bool tt
end.

(* For termination of recursive functions.  We don't name assertions, so use
   the type class mechanism to find it. *)
Definition _limit_reduces {_limit} (_acc:Acc (Zwf 0) _limit) `{ArithFact (_limit >= 0)} : Acc (Zwf 0) (_limit - 1).
refine (Acc_inv _acc _).
destruct H.
red.
omega.
Defined.

(* A version of well-foundedness of measures with a guard to ensure that
   definitions can be reduced without inspecting proofs, based on a coq-club
   thread featuring Barras, Gonthier and Gregoire, see
     https://sympa.inria.fr/sympa/arc/coq-club/2007-07/msg00014.html *)

Fixpoint pos_guard_wf {A:Type} {R:A -> A -> Prop} (p:positive) : well_founded R -> well_founded R :=
 match p with
 | xH => fun wfR x => Acc_intro x (fun y _ => wfR y)
 | xO p' => fun wfR x => let F := pos_guard_wf p' in Acc_intro x (fun y _ => F (F 
wfR) y)
 | xI p' => fun wfR x => let F := pos_guard_wf p' in Acc_intro x (fun y _ => F (F 
wfR) y)
 end.

Definition Zwf_guarded (z:Z) : Acc (Zwf 0) z :=
  match z with
  | Zpos p => pos_guard_wf p (Zwf_well_founded _) _
  | _ => Zwf_well_founded _ _
  end.


(*val whileM : forall 'rv 'vars 'e. 'vars -> ('vars -> monad 'rv bool 'e) ->
                ('vars -> monad 'rv 'vars 'e) -> monad 'rv 'vars 'e
let rec whileM vars cond body =
  cond vars >>= fun cond_val ->
  if cond_val then
    body vars >>= fun vars -> whileM vars cond body
  else return vars

val untilM : forall 'rv 'vars 'e. 'vars -> ('vars -> monad 'rv bool 'e) ->
                ('vars -> monad 'rv 'vars 'e) -> monad 'rv 'vars 'e
let rec untilM vars cond body =
  body vars >>= fun vars ->
  cond vars >>= fun cond_val ->
  if cond_val then return vars else untilM vars cond body

(*let write_two_regs r1 r2 vec =
  let is_inc =
    let is_inc_r1 = is_inc_of_reg r1 in
    let is_inc_r2 = is_inc_of_reg r2 in
    let () = ensure (is_inc_r1 = is_inc_r2)
                    "write_two_regs called with vectors of different direction" in
    is_inc_r1 in

  let (size_r1 : integer) = size_of_reg r1 in
  let (start_vec : integer) = get_start vec in
  let size_vec = length vec in
  let r1_v =
    if is_inc
    then slice vec start_vec (size_r1 - start_vec - 1)
    else slice vec start_vec (start_vec - size_r1 - 1) in
  let r2_v =
    if is_inc
    then slice vec (size_r1 - start_vec) (size_vec - start_vec)
    else slice vec (start_vec - size_r1) (start_vec - size_vec) in
  write_reg r1 r1_v >> write_reg r2 r2_v*)

*)

(* If we need to build an existential after a monadic operation, assume that
   we can do it entirely from the type. *)

Definition build_ex_m {rv e} {T:Type} (x:monad rv T e) {P:T -> Prop} `{H:forall x, ArithFact (P x)} : monad rv {x : T & ArithFact (P x)} e :=
  x >>= fun y => returnm (existT _ y (H y)).

Definition projT1_m {rv e} {T:Type} {P:T -> Prop} (x: monad rv {x : T & P x} e) : monad rv T e :=
  x >>= fun y => returnm (projT1 y).

Definition derive_m {rv e} {T:Type} {P Q:T -> Prop} (x : monad rv {x : T & P x} e) `{forall x, ArithFact (P x) -> ArithFact (Q x)} : monad rv {x : T & (ArithFact (Q x))} e :=
  x >>= fun y => returnm (build_ex (projT1 y)).
