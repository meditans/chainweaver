{-# LANGUAGE ConstraintKinds       #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE ExtendedDefaultRules  #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE KindSignatures        #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE QuasiQuotes           #-}
{-# LANGUAGE RecursiveDo           #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE StandaloneDeriving    #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TupleSections         #-}

-- | Confirmation dialog for deploying modules and calling functions on the
-- backend.
-- Copyright   :  (C) 2018 Kadena
-- License     :  BSD-style (see the file LICENSE)
--

module Frontend.UI.Dialogs.DeployConfirmation
  ( uiDeployConfirmation
  ) where

------------------------------------------------------------------------------
import           Control.Lens
import           Control.Monad
import           Data.Bifunctor
import           Data.Map                (Map)
import qualified Data.Map                as Map
import           Data.Set                (Set)
import qualified Data.Set                as Set
import           Data.Text               (Text)
import           Reflex
import           Reflex.Dom
import           Data.Void (Void)
------------------------------------------------------------------------------
import           Frontend.Backend
import           Frontend.Ide
import           Frontend.ModuleExplorer (HasModuleExplorerCfg (..))
import           Frontend.Wallet
import           Frontend.Wallet         (HasWallet (..))
import           Frontend.UI.Modal
import           Frontend.UI.Widgets
import           Frontend.UI.Button
------------------------------------------------------------------------------


-- | Confirmation dialog for deployments.
--
--   User can make sure to deploy to the right backend, has the right keysets,
--   the right keys, ...
uiDeployConfirmation
  :: MonadWidget t m
  => Ide a t
  -> m (IdeCfg Void t, Event t ())
uiDeployConfirmation ideL = do
  onClose <- modalHeader $ text "Deployment Settings"
  modalMain $ do
    transInfo <- modalBody $ do
      el "h3" $ text "Choose a server "

      let backends = ffor (_backend_backends $ _ide_backend ideL) $
            fmap (\(k, _) -> (k, textBackendName k)) . maybe [] Map.toList
          mkOptions bs = Map.fromList $ (Nothing, "Deployment Target") : map (first Just) bs
      d <- dropdown Nothing (mkOptions <$> backends) def

      signingKeys <- elClass "div" "key-chooser" $ do
        el "h3" $ text "Choose keys to sign with"
        signingKeysWidget $ _ide_wallet ideL
      pure $ do
        s <- signingKeys
        mb <- value d
        pure $ TransactionInfo s <$> mb

    modalFooter $ do
      onCancel <- cancelButton def "Cancel"
      text " "
      let isDisabled = maybe True (const False) <$> transInfo
      onConfirm <- confirmButton (def & uiButtonCfg_disabled .~ isDisabled) "Deploy"

      -- TODO: Use `backendCfg_deployCode` instead.
      let cfg = mempty & moduleExplorerCfg_deployEditor .~
            fmapMaybe id (tagPromptlyDyn transInfo onConfirm)
      pure (cfg, leftmost [onClose, onCancel, onConfirm])
