{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Interpreter where

import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Except
import Control.Monad.IO.Class

import qualified Data.Map as Map
import qualified Data.Set as Set

type Location = Integer
type Store = Map Location Variable
type Env = Map Ident Location

type Context = (Env, Mode, Maybe Variable)
type RetVal = ExceptT RuntimeError IO

type Interpreter a = StateT Store (ReaderT Context RetVal) a
type FunctionType = Ident -> [Variable] -> [Expr] -> Interpreter Context
