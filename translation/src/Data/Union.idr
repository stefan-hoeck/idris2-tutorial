||| An open union implementation as first introduced
||| in chapter *Predicates and Proof Search*
module Data.Union

import Data.Vect

%default total

--------------------------------------------------------------------------------
--          Predicates
--------------------------------------------------------------------------------

||| Predicate witnessing that a value is an element
||| of a vector.
public export
data Has : (v : a) -> (vs : Vect n a) -> Type where
  Z : Has v (v :: vs)
  S : Has v vs -> Has v (w :: vs)

||| Predicate witnessing that a value is an element
||| of a vector and listing the result of removing
||| said element from the vector.
public export
data Rem : (v : a) -> (vs : Vect (S n) a) -> (rem : Vect n a) -> Type where
  [search v vs]
  RZ : Rem v (v :: vs) vs
  RS : Rem v vs rem -> Rem v (w :: vs) (w :: rem)

--------------------------------------------------------------------------------
--          Union
--------------------------------------------------------------------------------

||| An *open union*, holding a single value of one
||| of the types listed in the index.
public export
data Union : (ts : Vect n Type) -> Type where
  U : (prf : Has t ts) -> (v : t) -> Union ts

||| Inject a value into an open union.
public export
inj : (v : t) -> Has t ts => Union ts
inj v = U %search v

--------------------------------------------------------------------------------
--          Decomposing Unions
--------------------------------------------------------------------------------

projImpl : Has t1 ts -> Has t2 ts -> t2 -> Maybe t1
projImpl Z     Z     v = Just v
projImpl (S x) (S y) v = projImpl x y v
projImpl Z     (S _) _ = Nothing
projImpl (S _)  Z    _ = Nothing

||| Try to extract a value of the given type
||| from a union.
public export
proj : (0 t : Type) -> Has t ts => Union ts -> Maybe t
proj _ (U ix v) = projImpl %search ix v

||| Like `proj` but with an implicit type argument.
public export
proj' : Has t ts => Union ts -> Maybe t
proj' = proj t

||| Decomposes a union: Either returns a value
||| of the given type or a new union where the
||| given type is no longer in the index.
public export
decomp :  (0 t : Type)
       -> (prf : Rem t ts rem )
       => Union ts
       -> Either t (Union rem)
decomp _ {prf = RZ}   (U Z v)     = Left v
decomp _ {prf = RZ}   (U (S x) v) = Right (U x v)
decomp _ {prf = RS x} (U Z v)     = Right (U Z v)
decomp t {prf = RS x} (U (S y) v) = case decomp t (U y v) of
  Left z          => Left z
  Right (U prf z) => Right (U (S prf) z)

||| Like `decomp` but with an implicit type argument.
public export
decomp' : Rem t ts rem => Union ts -> Either t (Union rem)
decomp' = decomp t

--------------------------------------------------------------------------------
--          Embedding Unions
--------------------------------------------------------------------------------

extendHasR : Has v vs -> Has v (vs ++ r)
extendHasR Z     = Z
extendHasR (S x) = S (extendHasR x)

||| Extends a union by appending additional types
||| to the list of possibilities.
public export
extendR : Union ts -> Union (ts ++ r)
extendR (U prf v) = U (extendHasR prf) v

extendHasL : {n : _} -> {0 r : Vect n _} -> Has v vs -> Has v (r ++ vs)
extendHasL {n = Z}   {r = []}     prf = prf
extendHasL {n = S k} {r = _ :: _} prf = S (extendHasL prf)

||| Extends a union by prepending additional types
||| to the list of possibilities. In order to implement this,
||| we need to shift the current index, therefore the
||| number of new types must be known a runtime.
public export
extendL : {n : _} -> {0 r : Vect n _} -> Union ts -> Union (r ++ ts)
extendL (U prf v) = U (extendHasL prf) v
