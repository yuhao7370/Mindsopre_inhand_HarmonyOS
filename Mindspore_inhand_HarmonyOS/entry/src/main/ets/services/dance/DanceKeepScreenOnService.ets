import {
  HarmonyKeepScreenOnWindowProvider,
  KeepScreenOnService,
  KeepScreenOnWindow,
  KeepScreenOnWindowProvider
} from '../window/KeepScreenOnService';

export interface DanceKeepScreenOnWindow extends KeepScreenOnWindow {}

export interface DanceKeepScreenOnWindowProvider extends KeepScreenOnWindowProvider {}

export class HarmonyDanceKeepScreenOnWindowProvider extends HarmonyKeepScreenOnWindowProvider {}

export class DanceKeepScreenOnService extends KeepScreenOnService {}
