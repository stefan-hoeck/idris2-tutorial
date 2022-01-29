||| A heterogeneous list. This was introduced in
||| chapter *Functor and Friends* and is also used in
||| later chapters
module Data.HList

import Data.Fin

%default total

public export
data HList : (ts : List Type) -> Type where
  Nil  : HList Nil
  (::) : (v : t) -> (vs : HList ts) -> HList (t :: ts)

public export
head : HList (t :: ts) -> t
head (v :: _) = v

public export
tail : HList (t :: ts) -> HList ts
tail (_ :: t) = t

public export
(++) : HList xs -> HList ys -> HList (xs ++ ys)
[]        ++ ws = ws
(v :: vs) ++ ws = v :: (vs ++ ws)

public export
indexList : (as : List a) -> Fin (length as) -> a
indexList (x :: _)   FZ    = x
indexList (_ :: xs) (FS y) = indexList xs y
indexList []        x impossible

public export
index : (ix : Fin (length ts)) -> HList ts -> indexList ts ix
index FZ     (v :: _)  = v
index (FS x) (_ :: vs) = index x vs
index ix [] impossible
