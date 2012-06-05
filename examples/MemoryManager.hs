{-# LANGUAGE TypeFamilies #-}
module MemoryManager where

import Data.Dynamic
import Data.IntMap
import SoOSiM

import MemoryManager.Types
import MemoryManager.Util

memoryManager :: MemoryManager -> MemState -> Input MemCommand -> Sim MemState
memoryManager _ s (Message content retAddr)
  | (Register addr sc src) <- content
  = yield MemoryManager $ s {addressLookup = (MemorySource addr sc src):(addressLookup s)}

  | (Read addr) <- content
  = do
    let src = checkAddress (addressLookup s) addr
    case (sourceId src) of
      Nothing -> do
        addrVal <- readMemory Nothing addr
        respond MemoryManager Nothing retAddr addrVal
        yield MemoryManager s
      Just remote -> do
        response <- invoke MemoryManager Nothing remote content
        respond MemoryManager Nothing retAddr response
        yield MemoryManager s

  | (Write addr val) <- content
  = do
    let src = checkAddress (addressLookup s) addr
    case (sourceId src) of
      Nothing -> do
        addrVal <- writeMemory Nothing addr val
        yield MemoryManager s
      Just remote -> do
        invokeAsync MemoryManager Nothing remote content (ignore MemoryManager)
        yield MemoryManager s

memoryManager _ s _ = yield MemoryManager s

instance ComponentInterface MemoryManager where
  type State MemoryManager   = MemState
  type Receive MemoryManager = MemCommand
  type Send MemoryManager    = Dynamic
  initState          = const (MemState [])
  componentName      = const "MemoryManager"
  componentBehaviour = memoryManager
