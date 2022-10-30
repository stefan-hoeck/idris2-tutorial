module Solutions.Folds

import Data.Maybe
import Data.SnocList
import Data.Vect

%default total

--------------------------------------------------------------------------------
--          Recursion
--------------------------------------------------------------------------------

-- 1

anyList : (a -> Bool) -> List a -> Bool
anyList p []        = False
anyList p (x :: xs) = case p x of
  False => anyList p xs
  True  => True

allList : (a -> Bool) -> List a -> Bool
allList p []        = True
allList p (x :: xs) = case p x of
  True  => allList p xs
  False => False

-- 2

findList : (a -> Bool) -> List a -> Maybe a
findList f []        = Nothing
findList f (x :: xs) = if f x then Just x else findList f xs

-- 3

collectList : (a -> Maybe b) -> List a -> Maybe b
collectList f []        = Nothing
collectList f (x :: xs) = case f x of
  Just vb => Just vb
  Nothing => collectList f xs

-- Note utility function `Data.Maybe.toMaybe` in the implementation
lookupList : Eq a => a -> List (a,b) -> Maybe b
lookupList va = collectList (\(k,v) => toMaybe (k == va) v)

-- 4

mapTR' : (a -> b) -> List a -> List b
mapTR' f = go Lin
  where go : SnocList b -> List a -> List b
        go sx []        = sx <>> Nil
        go sx (x :: xs) = go (sx :< f x) xs

-- 5

filterTR' : (a -> Bool) -> List a -> List a
filterTR' f = go Lin
  where go : SnocList a -> List a -> List a
        go sx []        = sx <>> Nil
        go sx (x :: xs) = if f x then go (sx :< x) xs else go sx xs

-- 6

mapMayTR : (a -> Maybe b) -> List a -> List b
mapMayTR f = go Lin
  where go : SnocList b -> List a -> List b
        go sx []        = sx <>> Nil
        go sx (x :: xs) = case f x of
          Just vb => go (sx :< vb) xs
          Nothing => go sx xs

catMaybesTR : List (Maybe a) -> List a
catMaybesTR = mapMayTR id

-- 7

concatTR : List a -> List a -> List a
concatTR xs ys = (Lin <>< xs) <>> ys

-- 8

bindTR : List a -> (a -> List b) -> List b
bindTR xs f = go Lin xs
  where go : SnocList b -> List a -> List b
        go sx []        = sx <>> Nil
        go sx (x :: xs) = go (sx <>< f x) xs

joinTR : List (List a) -> List a
joinTR = go Lin
  where go : SnocList a -> List (List a) -> List a
        go sx []        = sx <>> Nil
        go sx (x :: xs) = go (sx <>< x) xs

--------------------------------------------------------------------------------
--          A few Notes on Totality Checking
--------------------------------------------------------------------------------

record Tree a where
  constructor Node
  value  : a
  forest : List (Tree a)

Forest : Type -> Type
Forest = List . Tree

example : Tree Bits8
example = Node 0 [Node 1 [], Node 2 [Node 3 [], Node 4 [Node 5 []]]]

mutual
  treeSize : Tree a -> Nat
  treeSize (Node _ forest) = S $ forestSize forest

  forestSize : Forest a -> Nat
  forestSize []        = 0
  forestSize (x :: xs) = treeSize x + forestSize xs

-- 1

mutual
  treeDepth : Tree a -> Nat
  treeDepth (Node _ forest) = S $ forestDepth forest

  forestDepth : Forest a -> Nat
  forestDepth []        = 0
  forestDepth (x :: xs) = max (treeDepth x) (forestDepth xs)

-- 2

-- It's often easier to write complex interface implementations
-- via a utility function.
--
-- Of course, we could also use a `mutual` block as with
-- `treeSize` and `forestSize` here.
treeEq : Eq a => Tree a -> Tree a -> Bool
treeEq (Node v1 f1) (Node v2 f2) = v1 == v2 && go f1 f2
  where go : Forest a -> Forest a -> Bool
        go []        []        = True
        go (x :: xs) (y :: ys) = treeEq x y && go xs ys
        go _         _         = False

Eq a => Eq (Tree a) where (==) = treeEq

-- 3

treeMap : (a -> b) -> Tree a -> Tree b
treeMap f (Node value forest) = Node (f value) (go forest)
  where go : Forest a -> Forest b
        go []        = []
        go (x :: xs) = treeMap f x :: go xs

Functor Tree where map = treeMap

-- 4

treeShow : Show a => Prec -> Tree a -> String
treeShow p (Node value forest) =
  showCon p "Node" $ showArg value ++ case forest of
    []      => " []"
    x :: xs => " [" ++ treeShow Open x ++ go xs ++ "]"

  where go : Forest a -> String
        go []        = ""
        go (y :: ys) = ", " ++ treeShow Open y ++ go ys

Show a => Show (Tree a) where showPrec = treeShow

-- 5

mutual
  treeToVect : (tr : Tree a) -> Vect (treeSize tr) a
  treeToVect (Node value forest) = value :: forestToVect forest

  forestToVect : (f : Forest a) -> Vect (forestSize f) a
  forestToVect []        = []
  forestToVect (x :: xs) = treeToVect x ++ forestToVect xs

--------------------------------------------------------------------------------
--          Interface Foldable
--------------------------------------------------------------------------------

-- 1

data Crud : (i : Type) -> (a : Type) -> Type where
  Create : (value : a) -> Crud i a
  Update : (id : i) -> (value : a) -> Crud i a
  Read   : (id : i) -> Crud i a
  Delete : (id : i) -> Crud i a

Foldable (Crud i) where
  foldr acc st (Create value)   = acc value st
  foldr acc st (Update _ value) = acc value st
  foldr _   st (Read _)         = st
  foldr _   st (Delete _)       = st

  foldl acc st (Create value)   = acc st value
  foldl acc st (Update _ value) = acc st value
  foldl _   st (Read _)         = st
  foldl _   st (Delete _)       = st

  null (Create _)   = False
  null (Update _ _) = False
  null (Read _)     = True
  null (Delete _)   = True

  foldMap f (Create value)   = f value
  foldMap f (Update _ value) = f value
  foldMap _ (Read _)         = neutral
  foldMap _ (Delete _)       = neutral

  foldlM acc st (Create value)   = acc st value
  foldlM acc st (Update _ value) = acc st value
  foldlM _   st (Read _)         = pure st
  foldlM _   st (Delete _)       = pure st

  toList (Create v)   = [v]
  toList (Update _ v) = [v]
  toList (Read _)     = []
  toList (Delete _)   = []

-- 2

data Response : (e, i, a : Type) -> Type where
  Created : (id : i) -> (value : a) -> Response e i a
  Updated : (id : i) -> (value : a) -> Response e i a
  Found   : (values : List a) -> Response e i a
  Deleted : (id : i) -> Response e i a
  Error   : (err : e) -> Response e i a

Foldable (Response e i) where
  foldr acc st (Created _ value) = acc value st
  foldr acc st (Updated _ value) = acc value st
  foldr acc st (Found values)    = foldr acc st values
  foldr _   st (Deleted _)       = st
  foldr _   st (Error _)         = st

  foldl acc st (Created _ value) = acc st value
  foldl acc st (Updated _ value) = acc st value
  foldl acc st (Found values)    = foldl acc st values
  foldl _   st (Deleted _)       = st
  foldl _   st (Error _)         = st

  null (Created _ _)     = False
  null (Updated _ _)     = False
  null (Found values)    = null values
  null (Deleted _)       = True
  null (Error _)         = True

  foldMap f (Created _ value) = f value
  foldMap f (Updated _ value) = f value
  foldMap f (Found values)    = foldMap f values
  foldMap f (Deleted _)       = neutral
  foldMap f (Error _)         = neutral

  toList (Created _ value) = [value]
  toList (Updated _ value) = [value]
  toList (Found values)    = values
  toList (Deleted _)       = []
  toList (Error _)         = []

  foldlM acc st (Created _ value) = acc st value
  foldlM acc st (Updated _ value) = acc st value
  foldlM acc st (Found values)    = foldlM acc st values
  foldlM _   st (Deleted _)       = pure st
  foldlM _   st (Error _)         = pure st

-- 3

data List01 : (nonEmpty : Bool) -> Type -> Type where
  Nil  : List01 False a
  (::) : a -> List01 False a -> List01 ne a

list01ToList : List01 ne a -> List a
list01ToList = go Lin
  where go : SnocList a -> List01 ne' a -> List a
        go sx []        = sx <>> Nil
        go sx (x :: xs) = go (sx :< x) xs

list01FoldMap : Monoid m => (a -> m) -> List01 ne a -> m
list01FoldMap f = go neutral
  where go : m -> List01 ne' a -> m
        go vm []        = vm
        go vm (x :: xs) = go (vm <+> f x) xs


Foldable (List01 ne) where
  foldr acc st []        = st
  foldr acc st (x :: xs) = acc x (foldr acc st xs)

  foldl acc st []        = st
  foldl acc st (x :: xs) = foldl acc (acc st x) xs

  null []       = True
  null (_ :: _) = False

  toList = list01ToList

  foldMap = list01FoldMap

  foldlM _ st []        = pure st
  foldlM f st (x :: xs) = f st x >>= \st' => foldlM f st' xs

-- 4

mutual
  foldrTree : (el -> st -> st) -> st -> Tree el -> st
  foldrTree f v (Node value forest) = f value (foldrForest f v forest)

  foldrForest : (el -> st -> st) -> st -> Forest el -> st
  foldrForest _ v []        = v
  foldrForest f v (x :: xs) = foldrTree f (foldrForest f v xs) x

mutual
  foldlTree : (st -> el -> st) -> st -> Tree el -> st
  foldlTree f v (Node value forest) = foldlForest f (f v value) forest

  foldlForest : (st -> el -> st) -> st -> Forest el -> st
  foldlForest _ v []        = v
  foldlForest f v (x :: xs) = foldlForest f (foldlTree f v x) xs

mutual
  foldMapTree : Monoid m => (el -> m) -> Tree el -> m
  foldMapTree f (Node value forest) = f value <+> foldMapForest f forest

  foldMapForest : Monoid m => (el -> m) -> Forest el -> m
  foldMapForest _ []        = neutral
  foldMapForest f (x :: xs) = foldMapTree f x <+> foldMapForest f xs

mutual
  toListTree : Tree el -> List el
  toListTree (Node value forest) = value :: toListForest forest

  toListForest : Forest el -> List el
  toListForest []        = []
  toListForest (x :: xs) = toListTree x ++ toListForest xs

mutual
  foldlMTree : Monad m => (st -> el -> m st) -> st -> Tree el -> m st
  foldlMTree f v (Node value forest) =
    f v value >>= \v' => foldlMForest f v' forest

  foldlMForest : Monad m => (st -> el -> m st) -> st -> Forest el -> m st
  foldlMForest _ v []        = pure v
  foldlMForest f v (x :: xs) =
    foldlMTree f v x >>= \v' => foldlMForest f v' xs

Foldable Tree where
  foldr   = foldrTree
  foldl   = foldlTree
  foldMap = foldMapTree
  foldlM  = foldlMTree
  null _  = False
  toList  = toListTree

-- 5

record Comp (f,g : Type -> Type) (a : Type) where
  constructor MkComp
  unComp  : f (g a)

Foldable f => Foldable g => Foldable (Comp f g) where
  foldr f st (MkComp v)  = foldr (flip $ foldr f) st v
  foldl f st (MkComp v)  = foldl (foldl f) st v
  foldMap f (MkComp v)   = foldMap (foldMap f) v
  foldlM f st (MkComp v) = foldlM (foldlM f) st v
  toList (MkComp v)      = foldMap toList v
  null (MkComp v)        = all null v

record Product (f,g : Type -> Type) (a : Type) where
  constructor MkProduct
  fst : f a
  snd : g a

Foldable f => Foldable g => Foldable (Product f g) where
  foldr f st (MkProduct v w)  = foldr f (foldr f st w) v
  foldl f st (MkProduct v w)  = foldl f (foldl f st v) w
  foldMap f (MkProduct v w)   = foldMap f v <+> foldMap f w
  toList  (MkProduct v w)     = toList v ++ toList w
  null (MkProduct v w)        = null v && null w
  foldlM f st (MkProduct v w) = foldlM f st v >>= \st' => foldlM f st' w

--------------------------------------------------------------------------------
--          Tests
--------------------------------------------------------------------------------

iterateTR : Nat -> (a -> a) -> a -> List a
iterateTR k f = go k Lin
  where go : Nat -> SnocList a -> a -> List a
        go 0     sx _ = sx <>> Nil
        go (S k) sx x = go k (sx :< x) (f x)


values : List Integer
values = iterateTR 100000 (+1) 0

main : IO ()
main = do
  printLn . length $ mapTR' (*2)  values
  printLn . length $ filterTR' (\n => n `mod` 2 == 0)  values
  printLn . length $ mapMayTR (\n => toMaybe (n `mod` 2 == 1) "foo")  values
  printLn . length $ concatTR values values
  printLn . length $ bindTR [1..500] (\n => iterateTR n (+1) n)
