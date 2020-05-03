module SkelGrammar where

-- Haskell module generated by the BNF converter
import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Except
import Control.Monad.IO.Class
import Data.Map
import Data.String

-- import qualified Data.Map as Map
import qualified Data.Set as Set
import AbsGrammar
import ErrM

-- newtype Fun = Fun ([Value] -> Interpreter Value)
type Variable = Ident
type FName = Ident
type Location = Integer
data Value = Int Integer
  | Bool Bool 
  | String String
-- | Fun ([Value] -> Interpreter Value) todo 
-- | Array Int (Map.Map Int Location)
-- | Fun Fun
 deriving (Show, Eq, Ord)
newtype Fun = Fun ([Value] -> Interpreter Value)

type Store = Map Location Value
type EnvVar = Map Variable Location
type EnvFun = Map FName Fun

type Context = (EnvVar, EnvFun)

type Result = ExceptT String IO

type Interpreter a = StateT Store (ReaderT Context Result) a

-- type FunctionType = Ident -> [Variable] -> [Expr] -> Interpreter Context

showVal :: Value -> String
showVal (Int i) = show i
showVal (Bool b) 
  | b = "true"
  | otherwise = "false"
showVal (String s) = s
-- showVal (Fun f) = "function"  -- todo

failure :: Stmt -> Interpreter Context
failure x = do
  context <- ask
  lift $ lift $ lift $ putStrLn "Cos zapomniales zaimplementowac" -- todo xd czemu tyle liftów
  return $ context
-- transIdent :: Ident -> Interpreter 
-- transIdent x = case x of
--   Ident string -> failure x

interpret :: Program -> (Result ())
interpret p = do
  runReaderT (execStateT (transProgram p) empty) (empty, empty)
  return ()


transProgram :: Program -> Interpreter ()
transProgram (Program ds) = do
  context <- transTopDefs ds
  (Fun main) <- local (const context) $ getFun (Ident "main")
  local (const context) $ main []
  return ()


transTopDefs :: [TopDef] -> Interpreter Context
transTopDefs [] = ask
transTopDefs (d:ds) = do
  context <- transTopDef d
  newCont <- local (const context) $ transTopDefs ds
  return newCont

transTopDef :: TopDef -> Interpreter Context
transTopDef (FnDef funName args block) = do
  context <- ask
  let newFun = transTopDefHlp context funName args block 
  --   newCont2 <- local (const newCont1) $ transBlock block
    -- todo może jakieś rekurencja
  return $ setFun funName (Fun (newFun)) context

transTopDefHlp context funName args block  values = do
  newCont1 <- local (const context) $ transArguments args values-- params
  -- let newCont2 = setFun funName dupa newCont1 -- recursion
  -- local (const newCont2) $ transBlock block
  local (const newCont1) $ transBlock block
  return $ Int 0

getFun :: FName -> Interpreter Fun
getFun f = do
  context <- ask
  return $ snd context ! f 

setFun :: FName -> Fun -> Context -> Context
setFun name fun (envVar, envFun) = 
  let newEnvFun = insert name fun envFun
  in (envVar, newEnvFun)

next :: Interpreter Location
next = do
  store <- get
  let loc = if size store /= 0 then (fst $ findMax store) + 1 else 1
  put store
  return loc


transArguments :: [Arg] -> [Value]-> Interpreter Context
transArguments [] [] = ask
transArguments (var:vars) (val:vals) = do
  newCont1 <- transArgument var val
  newCont2 <- local (const newCont1) $ transArguments vars vals -- todo co robi to const?
  return newCont2
  -- loc <- alloc
  -- modify (\store -> insert loc val store)
  -- env' <- local (transArgument var val) $ transArguments



transArgument :: Arg -> Value-> Interpreter Context
transArgument var val = case var of
  Arg ident -> do
    loc <- next
    modify (\store -> insert loc val store)
    (envVar, envFun) <- ask
    let newEnvVar = insert ident loc envVar
    return (newEnvVar, envFun)
  CntsArg ident -> do
    lift $ lift $ lift $ putStrLn "TODO, nie zapomnij dodac constow" -- todo xd czemu tyle liftów
    newCont <- transArgument (Arg ident) val
    return newCont
 
transBlock :: Block -> Interpreter Context
transBlock (Block (stmt:stmts)) = do
  newCont1 <- transStmt stmt
  newCont2 <- local (const newCont1) (transBlock (Block stmts))
  return $ newCont2
-- transBlock (x:xs) = do
  -- return 0

   
transStmt :: Stmt -> Interpreter Context
transStmt x = case x of
  Empty -> do
    context <- ask
    return context
  BStmt block -> failure x
  DeclCon ident expr -> failure x
  DeclFun ident args block -> failure x

  Ass ident expr -> do -- todo dodać czysczenie pamieci
    val <- transExpr expr
    loc <- next
    (envVar, envFun) <- ask
    modify (\store -> insert loc val store)
    let newEnvVar = insert ident loc envVar
    return (newEnvVar, envFun)


  TupleAss ident exprs -> failure x
  TupleAss1 args exprs -> failure x
  TupleAss2 args expr -> failure x
  Incr ident -> failure x
  Decr ident -> failure x
  Ret expr -> failure x
  RetTuple exprs -> failure x
  VRet -> failure x
  Cond expr stmt -> failure x
  CondElse expr stmt1 stmt2 -> failure x
  While expr stmt -> failure x
  For ident expr1 expr2 stmt -> failure x
  ForIn ident1 ident2 stmt -> failure x
  Break -> failure x
  Conti -> failure x
  SExp expr -> failure x
  PrInt expr -> do
    val <- transExpr expr
    lift $ lift $  lift $ putStrLn $ showVal val
    context <- ask
    return context

  PrStr expr ->  do
    val <- transExpr expr
    lift $ lift $  lift $ putStrLn $ showVal val
    context <- ask
    return context
  Honk expr -> failure x
  Error -> failure x


transExprHlp :: Expr -> Expr -> (Value -> Value-> Interpreter Value) -> Interpreter Value
transExprHlp expr1 expr2 op = do
  val1 <- transExpr expr1
  val2 <- transExpr expr2 
  result <- op val1 val2
  return result

-- todo zmienic
transExpr :: Expr -> Interpreter Value
transExpr x = case x of
  EVar ident -> do 
    store <- get
    (envVar, _) <- ask
    -- member ident envVar -- todo brak zmiennej
    return $ store ! (envVar ! ident)

  ELitInt integer -> return $ Int $ integer
  ELitTrue -> return $ Bool $ True
  ELitFalse ->  return $ Bool $ False
--   EApp ident exprs -> failure x
  EString string -> return $ String $ string
--   EList exprs -> failure x
--   EList1 expr1 expr2 -> failure x
--   EAt ident expr -> failure x

  EMul expr1 mulop expr2 -> transExprHlp expr1 expr2 (transMulOp mulop)
  EAdd expr1 addop expr2 -> transExprHlp expr1 expr2 (transAddOp addop)
  ERel expr1 relop expr2 -> transExprHlp expr1 expr2 (transRelOp relop)

  Neg expr -> do
    val <- transExpr expr
    case val of
      Int i -> return $ Int $ ( -i)
      otherwise -> return $ Int $ 0 -- todo
  Not expr -> do
    val <- transExpr expr
    case val of
      Bool b -> return $ Bool $ (not b)
      otherwise -> return $ Bool $ False -- todo

  EAnd expr1 expr2 -> do
    val1 <- transExpr expr1
    case val1 of
      Bool b1 -> if b1
        then do -- todo jakby sie walilo to zmienic
          val2 <- transExpr expr2
          case val2 of
            Bool b1 -> return $ Bool $ b1
            otherwise -> return $ Bool $ False  -- todo
        else
          return $ Bool $ False
      otherwise -> return $ Bool $ False -- todo

  EOr expr1 expr2 -> do
    val1 <- transExpr expr1
    case val1 of
      Bool b1 -> if not b1
        then do
          val2 <- transExpr expr2
          case val2 of
            Bool b1 -> return $ Bool $ b1
            otherwise -> return $ Bool $ False  -- todo
        else
          return $ Bool $ False
      otherwise -> return $ Bool $ False -- todo

--   ELambda args block -> failure x
--   ELambdaS args block -> failure x
transAddOp :: AddOp -> Value -> Value -> Interpreter Value
transAddOp x (Int l) (Int r) = case x of
  Plus -> return $ Int $ l + r
  Minus -> return $ Int $ l - r
transAddOp Plus (String l) (String r) = return $ String $ l ++ r
transAddOp _ _ _ = do
  lift $ lift $ lift $ putStrLn "Wrong type AddOp" -- todo 
  return $ Int $ 0
transMulOp :: MulOp -> Value -> Value -> Interpreter Value
transMulOp x (Int l) (Int r) = case x of
  Times -> return $ Int $ l * r
  Div -> do
    lift $ lift $ lift $putStrLn "todo Div errorr" -- todo 
    if r /= 0 then
      return $ Int $ div l r
    else
      return $ Int $ 0
  Mod -> do
    lift $ lift $ lift $ putStrLn "todo Mod error" -- todo 
    if r > 0 then
      return $ Int $ mod l r
    else
      return $ Int $ 0
transMulOp _ _ _ = do
  lift $ lift $ lift $ putStrLn "Wrong type MulOp" -- todo 
  return $ Int $ 0

transRelOp :: RelOp -> Value -> Value -> Interpreter Value
transRelOp x (Int l) (Int r) = case x of
  LTH -> return $ Bool $ l < r
  LE -> return $ Bool $ l <= r
  GTH -> return $ Bool $ l > r
  GE -> return $ Bool $ l >= r
  EQU -> return $ Bool $ l == r
  NE -> return $ Bool $ l /= r
transRelOp _ _ _ = do
  lift $ lift $ lift $ putStrLn "Wrong type RelOp" -- todo 
  return $ Int $ 0
