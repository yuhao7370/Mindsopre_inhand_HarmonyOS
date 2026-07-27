export type QrCodeSaveSheetAction = 'open' | 'cancel' | 'saveSuccess' | 'saveFailed' | 'backdrop' | 'back';

export function qrCodeSheetActionForNativeDismiss(pressedBack: boolean): QrCodeSaveSheetAction {
  return pressedBack ? 'back' : 'backdrop';
}

export function qrCodeSaveSheetVisibleAfterAction(
  currentVisible: boolean,
  action: QrCodeSaveSheetAction
): boolean {
  if (action === 'open') {
    return true;
  }
  if (action === 'saveFailed') {
    return currentVisible;
  }
  return false;
}

export function shouldStartQrCodeSave(saveInFlight: boolean): boolean {
  return !saveInFlight;
}
