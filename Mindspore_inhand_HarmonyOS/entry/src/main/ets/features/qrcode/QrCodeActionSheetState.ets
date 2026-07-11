export type QrCodeSaveSheetAction = 'open' | 'cancel' | 'save' | 'backdrop' | 'back';

export function qrCodeSaveSheetVisibleAfterAction(
  currentVisible: boolean,
  action: QrCodeSaveSheetAction
): boolean {
  if (action === 'open') {
    return true;
  }
  return false;
}
