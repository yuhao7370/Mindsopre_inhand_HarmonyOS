export function webPageFailedAfterRequest(currentFailed: boolean, isMainFrame: boolean): boolean {
  return currentFailed || isMainFrame;
}
