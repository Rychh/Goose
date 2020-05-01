-- {-# LANGUAGE TemplateHaskell #-}
-- {-# LANGUAGE TypeSynonymInstances #-}

-- module Interpreter where

-- import Control.Monad.Reader
-- import Control.Monad.State
-- import Control.Monad.Except
-- import Control.Monad.IO.Class

-- import qualified Data.Map as Map
-- import qualified Data.Set as Set

-- type Variable = Ident
-- type FName = Ident
-- type Location = Integer
-- type Store = Map Location Variable
-- type Env = Map Variable Location

-- data Val = Int Int | Bool Bool | Array Int (Map Int Loc)
--  deriving (Show, Eq, Ord)
 
-- newtype Fun = Fun ([Val] -> Interpreter Val)

-- type Context = (Env, Mode, Maybe Variable)

-- type Interpreter a = StateT Store (ReaderT Context Result) a
-- type FunctionType = Ident -> [Variable] -> [Expr] -> Interpreter Context

-- getVarLoc :: Var -> Interpreter Loc
-- getVarLoc v = do
--   env <- ask
--   return $ fst env ! v

-- setLoc :: Ident -> Location -> Env -> Env
-- setLoc v loc env =
--   let newEnv = insert v loc env
--   in newEnv

-- setFun :: FName -> FunctionType -> Env -> Env
-- setFun name fun (eVar, eFun) = 
--   let newEFun = insert name fun eFun
--   in (eVar, newEFun)

-- -- getFun :: FName -> Interpreter Fun
-- -- getFun f = do
--   env <- ask
--   return $ snd env ! f 
  
-- getVarVal :: Var -> Interpreter Val
-- getVarVal v = do
--   store <- get
--   loc <- getVarLoc v
--   return $ store ! loc

-- setVarVal :: Var -> Val -> Interpreter ()
-- setVarVal var val = do
--   loc <- getVarLoc var
--   modify $ insert loc val

-- getLocVal :: Loc -> Interpreter Val
-- getLocVal loc = do
--   store <- get
--   return $ store ! loc

-- showVal :: Val -> String
-- showVal (Int i) = show i
-- showVal (Bool b)
--   | b = "true"
--   | otherwise = "false"
-- showVal (Array _ _) = "array"
-- showVal (Mapp _) = "map"
-- showVal (Structt _) = "struct"
-- showVal Null = "null"