import { PermissionRequestSummary } from '../permissions/PermissionService';

export type SplashStartupPermissionState = 'ready' | 'blocked';

export interface SplashStartupTransition {
  readonly permissionState: SplashStartupPermissionState;
  readonly showPermissionDialog: boolean;
  readonly startCountdown: boolean;
  readonly finishImmediately: boolean;
}

export interface SplashFinishAction {
  readonly finishSplash: boolean;
}

export interface SplashRetryPermissionAction {
  readonly showPermissionDialog: boolean;
  readonly requestPermissions: boolean;
}

export function splashStartupPermissionStateForRequest(
  request: PermissionRequestSummary
): SplashStartupPermissionState {
  return request.ok ? 'ready' : 'blocked';
}

export function splashStartupPermissionStateForMissingContext(): SplashStartupPermissionState {
  return 'blocked';
}

export function canFinishSplashForStartupPermissionState(state: SplashStartupPermissionState): boolean {
  return state === 'ready';
}

export function shouldConsumeSplashBackPress(): boolean {
  return true;
}

export function shouldConsumeIndexBackPress(showMainPage: boolean): boolean {
  return !showMainPage && shouldConsumeSplashBackPress();
}

export function splashStartupTransitionForRequest(request: PermissionRequestSummary): SplashStartupTransition {
  const state = splashStartupPermissionStateForRequest(request);
  return splashStartupTransitionForState(state);
}

export function splashStartupTransitionForRequestAfterPrivacyAccept(
  request: PermissionRequestSummary
): SplashStartupTransition {
  const state = splashStartupPermissionStateForRequest(request);
  if (state === 'ready') {
    return {
      permissionState: state,
      showPermissionDialog: false,
      startCountdown: false,
      finishImmediately: true
    };
  }
  return splashStartupTransitionForState(state);
}

export function splashStartupTransitionForMissingContext(): SplashStartupTransition {
  return splashStartupTransitionForState(splashStartupPermissionStateForMissingContext());
}

export function finishSplashActionForStartupPermissionState(
  state: SplashStartupPermissionState
): SplashFinishAction {
  return {
    finishSplash: canFinishSplashForStartupPermissionState(state)
  };
}

export function splashRetryPermissionAction(): SplashRetryPermissionAction {
  return {
    showPermissionDialog: false,
    requestPermissions: true
  };
}

function splashStartupTransitionForState(state: SplashStartupPermissionState): SplashStartupTransition {
  return {
    permissionState: state,
    showPermissionDialog: state === 'blocked',
    startCountdown: state === 'ready',
    finishImmediately: false
  };
}
