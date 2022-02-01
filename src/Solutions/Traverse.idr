module Solutions.Traverse

import Control.Applicative.Const
import Control.Monad.Identity
import Data.HList
import Data.List1
import Data.Singleton
import Data.Vect

%default total

record State state a where
  constructor ST
  runST : state -> (state,a)

get : State state state
get = ST $ \s => (s,s)

put : state -> State state ()
put v = ST $ \_ => (v,())

modify : (state -> state) -> State state ()
modify f = ST $ \v => (f v,())

runState : state -> State state a -> (state, a)
runState = flip runST

evalState : state -> State state a -> a
evalState s = snd . runState s

execState : state -> State state a -> state
execState s = fst . runState s

Functor (State state) where
  map f (ST run) = ST $ \s => let (s2,va) = run s in (s2, f va)

Applicative (State state) where
  pure v = ST $ \s => (s,v)
  ST fun <*> ST val = ST $ \s =>
    let (s2, f)  = fun s
        (s3, va) = val s2
     in (s3, f va)

Monad (State state) where
  ST val >>= f = ST $ \s =>
    let (s2, va) = val s
     in runST (f va) s2

--------------------------------------------------------------------------------
--          Reading CSV Tables
--------------------------------------------------------------------------------

-- 1

mapFromTraverse : Traversable t => (a -> b) -> t a -> t b
mapFromTraverse f = runIdentity . traverse (Id . f)

-- 2

-- Since Idris can't infer the type of `b` the call to `MkConst`, we have
-- to pass a value (which we can choose freely) explicitly.
foldMapFromTraverse : Traversable t => Monoid m => (a -> m) -> t a -> m
foldMapFromTraverse f = runConst . traverse (MkConst {b = ()}. f)

-- 3

interface Functor t => Foldable t => Traversable' t where
  traverse' : Applicative f => (a -> f b) -> t a -> f (t b)

Traversable' List where
  traverse' f Nil       = pure Nil
  traverse' f (x :: xs) = [| f x :: traverse' f xs |]

Traversable' List1 where
  traverse' f (h ::: t) = [| f h ::: traverse' f t |]

Traversable' (Either e) where
  traverse' f (Left ve)  = pure $ Left ve
  traverse' f (Right va) = Right <$> f va

Traversable' Maybe where
  traverse' f Nothing   = pure Nothing
  traverse' f (Just va) = Just <$> f va

-- 4

data List01 : (nonEmpty : Bool) -> Type -> Type where
  Nil  : List01 False a
  (::) : a -> List01 False a -> List01 ne a

Functor (List01 ne) where
  map f Nil       = Nil
  map f (x :: xs) = f x :: map f xs

Foldable (List01 ne) where
  foldr acc st []        = st
  foldr acc st (x :: xs) = acc x (foldr acc st xs)

Traversable (List01 ne) where
  traverse _ Nil       = pure Nil
  traverse f (x :: xs) = [| f x :: traverse f xs |]

-- 5

record Tree a where
  constructor Node
  value  : a
  forest : List (Tree a)

Forest : Type -> Type
Forest = List . Tree

treeMap : (a -> b) -> Tree a -> Tree b
treeMap f (Node value forest) = Node (f value) (go forest)
  where go : Forest a -> Forest b
        go []        = []
        go (x :: xs) = treeMap f x :: go xs

Functor Tree where map = treeMap

mutual
  foldrTree : (el -> st -> st) -> st -> Tree el -> st
  foldrTree f v (Node value forest) = f value (foldrForest f v forest)

  foldrForest : (el -> st -> st) -> st -> Forest el -> st
  foldrForest _ v []        = v
  foldrForest f v (x :: xs) = foldrTree f (foldrForest f v xs) x

Foldable Tree where
  foldr   = foldrTree

mutual
  traverseTree : Applicative f => (a -> f b) -> Tree a -> f (Tree b)
  traverseTree g (Node v fo) = [| Node (g v) (traverseForest g fo) |]

  traverseForest : Applicative f => (a -> f b) -> Forest a -> f (Forest b)
  traverseForest g []        = pure []
  traverseForest g (x :: xs) = [| traverseTree g x :: traverseForest g xs |]

Traversable Tree where
  traverse = traverseTree

-- 6

data Crud : (i : Type) -> (a : Type) -> Type where
  Create : (value : a) -> Crud i a
  Update : (id : i) -> (value : a) -> Crud i a
  Read   : (id : i) -> Crud i a
  Delete : (id : i) -> Crud i a

Functor (Crud i) where
  map f (Create value)    = Create $ f value
  map f (Update id value) = Update id $ f value
  map f (Read id)         = Read id
  map f (Delete id)       = Delete id

Foldable (Crud i) where
  foldr acc st (Create value)   = acc value st
  foldr acc st (Update _ value) = acc value st
  foldr _   st (Read _)         = st
  foldr _   st (Delete _)       = st

Traversable (Crud i) where
  traverse f (Create value)    = Create <$> f value
  traverse f (Update id value) = Update id <$> f value
  traverse f (Read id)         = pure $ Read id
  traverse f (Delete id)       = pure $ Delete id

-- 7

data Response : (e, i, a : Type) -> Type where
  Created : (id : i) -> (value : a) -> Response e i a
  Updated : (id : i) -> (value : a) -> Response e i a
  Found   : (values : List a) -> Response e i a
  Deleted : (id : i) -> Response e i a
  Error   : (err : e) -> Response e i a

Functor (Response e i) where
  map f (Created id value) = Created id $ f value
  map f (Updated id value) = Updated id $ f value
  map f (Found values)     = Found $ map f values
  map _ (Deleted id)       = Deleted id
  map _ (Error err)        = Error err

Foldable (Response e i) where
  foldr acc st (Created _ value) = acc value st
  foldr acc st (Updated _ value) = acc value st
  foldr acc st (Found values)    = foldr acc st values
  foldr _   st (Deleted _)       = st
  foldr _   st (Error _)         = st

Traversable (Response e i) where
  traverse f (Created id value) = Created id <$> f value
  traverse f (Updated id value) = Updated id <$> f value
  traverse f (Found values)     = Found <$> traverse f values
  traverse _ (Deleted id)       = pure $ Deleted id
  traverse _ (Error err)        = pure $ Error err

-- 8

record Comp (f,g : Type -> Type) (a : Type) where
  constructor MkComp
  unComp  : f (g a)

Functor f => Functor g => Functor (Comp f g) where
  map fun = MkComp . (map . map) fun . unComp

Foldable f => Foldable g => Foldable (Comp f g) where
  foldr f st (MkComp v)  = foldr (flip $ foldr f) st v

Traversable f => Traversable g => Traversable (Comp f g) where
  traverse fun = map MkComp . (traverse . traverse) fun . unComp

record Product (f,g : Type -> Type) (a : Type) where
  constructor MkProduct
  fst : f a
  snd : g a

Functor f => Functor g => Functor (Product f g) where
  map fun (MkProduct fa ga) = MkProduct (map fun fa) (map fun ga)

Foldable f => Foldable g => Foldable (Product f g) where
  foldr f st (MkProduct v w)  = foldr f (foldr f st w) v

Traversable f => Traversable g => Traversable (Product f g) where
  traverse fun (MkProduct fa ga) =
    [| MkProduct (traverse fun fa) (traverse fun ga) |]

--------------------------------------------------------------------------------
--          Programming with State
--------------------------------------------------------------------------------

-- 1

rnd : Bits64 -> Bits64
rnd seed = (437799614237992725 * seed) `mod` 2305843009213693951

Gen : Type -> Type
Gen = State Bits64

bits64 : Gen Bits64
bits64 = get <* modify rnd

range64 : (upper : Bits64) -> Gen Bits64
range64 18446744073709551615 = bits64
range64 n                    = (`mod` (n + 1)) <$> bits64

interval64 : (a,b : Bits64) -> Gen Bits64
interval64 a b =
  let mi = min a b
      ma = max a b
   in (mi +) <$> range64 (ma - mi)

interval : Num n => Cast n Bits64 => (a,b : n) -> Gen n
interval a b = fromInteger . cast <$> interval64 (cast a) (cast b)

bool : Gen Bool
bool = (== 0) <$> range64 1

fin : {n : Nat} -> Gen (Fin $ S n)
fin = (\x => fromMaybe FZ $ natToFin x _) <$> interval 0 n

element : {n : _} -> Vect (S n) a -> Gen a
element vs = (`index` vs) <$> fin

vect : {n : _} -> Gen a -> Gen (Vect n a)
vect = sequence . replicate n

list : Gen Nat -> Gen a -> Gen (List a)
list gnat ga = gnat >>= \n => toList <$> vect {n} ga

testGen : Bits64 -> Gen a -> Vect 10 a
testGen seed = evalState seed . vect

choice : {n : _} -> Vect (S n) (Gen a) -> Gen a
choice gens = element gens >>= id

either : Gen a -> Gen b -> Gen (Either a b)
either ga gb = choice [Left <$> ga, Right <$> gb]

printableAscii : Gen Char
printableAscii = chr <$> interval 32 126

string : Gen Nat -> Gen Char -> Gen String
string gn = map pack . list gn

namespace HListF

  public export
  data HListF : (f : Type -> Type) -> (ts : List Type) -> Type where
    Nil  : HListF f []
    (::) : (x : f t) -> (xs : HListF f ts) -> HListF f (t :: ts)

hlist : HListF Gen ts -> Gen (HList ts)
hlist Nil        = pure Nil
hlist (gh :: gt) = [| gh :: hlist gt |]

hlistT : Applicative f => HListF f ts -> f (HList ts)
hlistT Nil        = pure Nil
hlistT (fh :: ft) = [| fh :: hlistT ft |]

-- 2

record IxState s t a where
  constructor IxST
  runIxST : s -> (t,a)

Functor (IxState s t) where
  map f (IxST run) = IxST $ \vs => let (vt,va) = run vs in (vt, f va)

pure : a -> IxState s s a
pure va = IxST $ \vs => (vs,va)

(<*>) : IxState r s (a -> b) -> IxState s t a -> IxState r t b
IxST ff <*> IxST fa = IxST $ \vr =>
  let (vs,f)  = ff vr
      (vt,va) = fa vs
   in (vt, f va)

(>>=) : IxState r s a -> (a -> IxState s t b) -> IxState r t b
IxST fa >>= f = IxST $ \vr =>
  let (vs,va) = fa vr in runIxST (f va) vs

(>>) : IxState r s () -> IxState s t a -> IxState r t a
IxST fu >> IxST fb = IxST $ fb . fst . fu

namespace IxMonad
  interface Functor (m s t) =>
            IxApplicative (0 m : Type -> Type -> Type -> Type) where
    pure : a -> m s s a
    (<*>) : m r s (a -> b) -> m s t a -> m r t b

  interface IxApplicative m => IxMonad m where
    (>>=) : m r s a -> (a -> m s t b) -> m r t b

  IxApplicative IxState where
    pure = Traverse.pure
    (<*>) = Traverse.(<*>)

  IxMonad IxState where
    (>>=) = Traverse.(>>=)

namespace IxState
  get : IxState s s s
  get = IxST $ \vs => (vs,vs)

  put : t -> IxState s t ()
  put vt = IxST $ \_ => (vt,())

  modify : (s -> t) -> IxState s t ()
  modify f = IxST $ \vs => (f vs, ())

  runState : s -> IxState s t a -> (t,a)
  runState = flip runIxST

  evalState : s -> IxState s t a -> a
  evalState vs = snd . runState vs

  execState : s -> IxState s t a -> t
  execState vs = fst . runState vs

Applicative (IxState s s) where
  pure = Traverse.pure
  (<*>) = Traverse.(<*>)

Monad (IxState s s) where
  (>>=) = Traverse.(>>=)
  join = (>>= id)

--------------------------------------------------------------------------------
--          The Power of Composition
--------------------------------------------------------------------------------

-- 1

data Tagged : (tag, value : Type) -> Type where
  Tag  : tag -> value -> Tagged tag value
  Pure : value -> Tagged tag value

Functor (Tagged tag) where
  map f (Tag x y) = Tag x (f y)
  map f (Pure x)  = Pure (f x)

Foldable (Tagged tag) where
  foldr f acc (Tag _ x) = f x acc
  foldr f acc (Pure x)  = f x acc

Traversable (Tagged tag) where
  traverse f (Tag x y) = Tag x <$> f y
  traverse f (Pure x)  = Pure <$> f x

Bifunctor Tagged where
  bimap f g (Tag x y) = Tag (f x) (g y)
  bimap _ g (Pure x)  = Pure (g x)

  mapFst f (Tag x y) = Tag (f x) y
  mapFst _ (Pure x)  = Pure x

  mapSnd g (Tag x y) = Tag x (g y)
  mapSnd g (Pure x)  = Pure (g x)

Bifoldable Tagged where
  bifoldr f g acc (Tag x y) = f x (g y acc)
  bifoldr f g acc (Pure x)  = g x acc

  bifoldl f g acc (Tag x y) = g (f acc x) y
  bifoldl _ g acc (Pure x)  = g acc x

  binull _ = False


Bitraversable Tagged where
  bitraverse f g (Tag x y) = [| Tag (f x) (g y) |]
  bitraverse _ g (Pure x)  = Pure <$> g x

-- 2

record Biff (p : Type -> Type -> Type) (f,g : Type -> Type) (a,b : Type) where
  constructor MkBiff
  runBiff : p (f a) (g b)

Bifunctor p => Functor f => Functor g => Bifunctor (Biff p f g) where
  bimap ff fg = MkBiff .  bimap (map ff) (map fg) . runBiff

Bifoldable p => Foldable f => Foldable g => Bifoldable (Biff p f g) where
  bifoldr ff fg acc = bifoldr (flip $ foldr ff) (flip $ foldr fg) acc . runBiff

Bitraversable p => Traversable f => Traversable g =>
  Bitraversable (Biff p f g) where
    bitraverse ff fg =
      map MkBiff . bitraverse (traverse ff) (traverse fg) . runBiff

record Tannen (f : Type -> Type) (p : Type -> Type -> Type) (a,b : Type) where
  constructor MkTannen
  runTannen : f (p a b)

Bifunctor p => Functor f => Bifunctor (Tannen f p) where
  bimap ff fg = MkTannen .  map (bimap ff fg) . runTannen

Bifoldable p => Foldable f => Bifoldable (Tannen f p) where
  bifoldr ff fg acc = foldr (flip $ bifoldr ff fg) acc . runTannen

Bitraversable p => Traversable f => Bitraversable (Tannen f p) where
  bitraverse ff fg = map MkTannen . traverse (bitraverse ff fg) . runTannen
