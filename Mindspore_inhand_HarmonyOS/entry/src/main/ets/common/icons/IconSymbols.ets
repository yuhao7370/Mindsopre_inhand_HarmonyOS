export function iconLabel(token: string): string {
  switch (token) {
    case 'rocket':
      return 'E';
    case 'college':
      return 'C';
    case 'me':
      return 'M';
    case 'people':
      return 'P';
    case 'image':
      return 'S';
    case 'grid':
      return 'I';
    case 'hand':
      return 'G';
    case 'dance':
      return 'D';
    case 'poetry':
      return 'Po';
    case 'text':
      return 'T';
    case 'translate':
      return 'Tr';
    case 'photo':
      return 'O';
    case 'camera':
      return 'R';
    case 'style':
      return 'St';
    case 'model':
      return 'M';
    case 'summary':
      return 'S';
    case 'cloud':
      return 'C';
    case 'new':
      return 'Q';
    case 'train':
      return 'T';
    case 'inference':
      return 'I';
    case 'app':
      return 'A';
    case 'video':
      return 'V';
    case 'faq':
      return '?';
    case 'forum':
      return 'F';
    case 'share':
      return 'S';
    case 'qr':
      return 'QR';
    case 'star':
      return '*';
    case 'official':
      return 'W';
    case 'code':
      return '<>';
    case 'feedback':
      return 'F';
    case 'version':
      return 'V';
    case 'privacy':
      return 'P';
    default:
      return token.length <= 2 ? token : token.substring(0, 2).toUpperCase();
  }
}

export function iconMediaName(token: string): string {
  switch (token) {
    case 'people':
      return 'btn_posenet';
    case 'image':
      return 'btn_segment';
    case 'grid':
      return 'btn_classification';
    case 'hand':
      return 'btn_gesture_recognition';
    case 'dance':
      return 'btn_scene';
    case 'poetry':
      return 'btn_intelligent_poetry';
    case 'text':
      return 'btn_text_extraction';
    case 'translate':
      return 'btn_text_translation';
    case 'scene':
      return 'btn_scene';
    case 'photo':
      return 'btn_test';
    case 'camera':
      return 'btn_video';
    case 'style':
      return 'btn_style';
    case 'model':
      return 'btn_test';
    case 'share':
      return 'me_share';
    case 'qr':
      return 'me_qr_code';
    case 'star':
      return 'me_up';
    case 'official':
      return 'me_official';
    case 'code':
      return 'me_official_code';
    case 'feedback':
      return 'me_qa';
    case 'version':
      return 'me_version';
    case 'go':
      return 'me_go';
    default:
      return '';
  }
}

export function iconMediaResource(token: string): Resource | undefined {
  switch (token) {
    case 'people':
      return $r('app.media.btn_posenet');
    case 'image':
      return $r('app.media.btn_segment');
    case 'grid':
      return $r('app.media.btn_classification');
    case 'hand':
      return $r('app.media.btn_gesture_recognition');
    case 'dance':
      return $r('app.media.btn_scene');
    case 'poetry':
      return $r('app.media.btn_intelligent_poetry');
    case 'text':
      return $r('app.media.btn_text_extraction');
    case 'translate':
      return $r('app.media.btn_text_translation');
    case 'scene':
      return $r('app.media.btn_scene');
    case 'photo':
      return $r('app.media.btn_test');
    case 'camera':
      return $r('app.media.btn_video');
    case 'style':
      return $r('app.media.btn_style');
    case 'model':
      return $r('app.media.btn_test');
    case 'share':
      return $r('app.media.me_share');
    case 'qr':
      return $r('app.media.me_qr_code');
    case 'star':
      return $r('app.media.me_up');
    case 'official':
      return $r('app.media.me_official');
    case 'code':
      return $r('app.media.me_official_code');
    case 'feedback':
      return $r('app.media.me_qa');
    case 'version':
      return $r('app.media.me_version');
    case 'go':
      return $r('app.media.me_go');
    default:
      return undefined;
  }
}
