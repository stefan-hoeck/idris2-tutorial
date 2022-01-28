module Solutions.Folds

import Data.Maybe
import Data.SnocList

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

mapTR : (a -> b) -> List a -> List b
mapTR f = go Lin
  where go : SnocList b -> List a -> List b
        go sx []        = sx <>> Nil
        go sx (x :: xs) = go (sx :< f x) xs

-- 5

filterTR : (a -> Bool) -> List a -> List a
filterTR f = go Lin
  where go : SnocList a -> List a -> List a
        go sx []        = sx <>> Nil
        go sx (x :: xs) = if f x then go (sx :< x) xs else go sx xs

-- 6

mapMaybeTR : (a -> Maybe b) -> List a -> List b
mapMaybeTR f = go Lin
  where go : SnocList b -> List a -> List b
        go sx []        = sx <>> Nil
        go sx (x :: xs) = case f x of
          Just vb => go (sx :< vb) xs
          Nothing => go sx xs

catMaybesTR : List (Maybe a) -> List a
catMaybesTR = mapMaybeTR id

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

-- 1

depth : Tree a -> Nat
depth (Node _ forest) = go 0 forest
  where go : Nat -> Forest a -> Nat
        go k []        = k
        go k (x :: xs) = go (max k $ depth x + 1) xs

-- 2

-- It's often easier to write complex interface implementations
-- via a utility function.
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

showTree : Show a => Prec -> Tree a -> String
showTree p (Node value forest) =
  showCon p "Node" $ showArg value ++ case forest of
    []      => " []"
    x :: xs => " [" ++ showTree Open x ++ go xs ++ "]"

  where go : Forest a -> String
        go []        = ""
        go (y :: ys) = ", " ++ showTree Open y ++ go ys

Show a => Show (Tree a) where showPrec = showTree

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
  printLn . length $ mapTR (*2)  values
  printLn . length $ filterTR (\n => n `mod` 2 == 0)  values
  printLn . length $ mapMaybeTR (\n => toMaybe (n `mod` 2 == 1) "foo")  values
  printLn . length $ concatTR values values
  printLn . length $ bindTR [1..500] (\n => iterateTR n (+1) n)
