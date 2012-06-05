{-# LANGUAGE FlexibleContexts #-}
module SoOSiM.Simulator.Util where

import           Control.Concurrent.STM (TVar,modifyTVar)
import           Control.Monad.State    (gets,lift,modify)
import           Data.Dynamic           (Dynamic,Typeable)
import qualified Data.IntMap            as IM
import qualified Data.Map               as Map

import SoOSiM.Types
import SoOSiM.Util

modifyNode ::
  NodeId
  -- ^ ID of the node you want to update
  -> (Node -> Node)
  -- ^ Update function
  -> SimMonad ()
modifyNode i f =
  modify (\s -> s {nodes = IM.adjust f i (nodes s)})

modifyNodeM ::
  NodeId
  -- ^ ID of the node you want to update
  -> (Node -> SimMonad ())
  -- ^ Update function
  -> SimMonad ()
modifyNodeM i f = do
  ns <- gets nodes
  f $ ns IM.! i

componentNode ::
  ComponentId
  -> SimMonad NodeId
componentNode cId = do
  ns <- gets nodes
  let (node:_) = IM.elems $ IM.filter (\n -> IM.member cId (nodeComponents n)) ns
  return (nodeId node)

updateMsgBuffer ::
  ComponentId
  -- ^ Recipient component ID
  -> Input Dynamic
  -- ^ Actual message
  -> Node
  -- ^ Node containing the component
  -> SimMonad ()
updateMsgBuffer recipient msg@(Message _ (RA (sender,_))) node = do
    let ce = (nodeComponents node) IM.! recipient
    lift $ modifyTVar (msgBuffer ce) (\msgs -> msgs ++ [msg])
    lift $ modifyTVar (simMetaData ce)
            (\mData -> mData {msgsReceived = Map.insertWith (+) sender 1
                                              (msgsReceived mData)})

updateMsgBuffer _ _ _ = return ()

incrSendCounter ::
  ComponentId
  -- ^ RecipientID
  -> ComponentId
  -- ^ SenderId
  -> Node
  -- ^ Node containing the sender
  -> SimMonad ()
incrSendCounter recipient sender node = do
  let ce = (nodeComponents node) IM.! sender
  lift $ modifyTVar (simMetaData ce)
          (\mData -> mData {msgsSend = Map.insertWith (+) recipient 1
                                        (msgsSend mData)})

updateTraceBuffer ::
  ComponentId
  -> String
  -> Node
  -> Node
updateTraceBuffer cmpId msg node =
    node { nodeComponents = f (nodeComponents node)}
  where
    f ccs = IM.adjust g cmpId ccs
    g cc  = cc { traceMsgs = msg:(traceMsgs cc)}

incrIdleCount, incrWaitingCount, incrRunningCount ::
  TVar SimMetaData
  -> SimMonad ()
incrIdleCount    tv = lift $ modifyTVar tv (\mdata -> mdata
                              {cyclesIdling = cyclesIdling  mdata + 1})
incrWaitingCount tv = lift $ modifyTVar tv (\mdata -> mdata
                              {cyclesWaiting = cyclesWaiting mdata + 1})
incrRunningCount tv = lift $ modifyTVar tv (\mdata -> mdata
                              {cyclesRunning = cyclesRunning mdata + 1})


fromDynMsg ::
  (ComponentInterface i, Typeable (Receive i))
  => i
  -> Input Dynamic
  -> Input (Receive i)
fromDynMsg _ (Message content retChan) =
  Message (unmarshall "fromDynMsg" content) retChan
fromDynMsg _ Tick = Tick

returnAddress ::
  ReturnAddress
  -> ComponentId
returnAddress = fst . unRA