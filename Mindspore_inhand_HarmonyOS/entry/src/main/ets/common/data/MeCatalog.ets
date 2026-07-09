export interface MeItem {
  readonly id: string;
  readonly title: string;
  readonly icon: string;
  readonly visibleByDefault: boolean;
}

export const meItems: MeItem[] = [
  { id: 'share', title: 'Share', icon: 'share', visibleByDefault: false },
  { id: 'qr', title: 'My QR Code', icon: 'qr', visibleByDefault: false },
  { id: 'star', title: 'Star', icon: 'star', visibleByDefault: false },
  { id: 'official', title: 'Official Website', icon: 'official', visibleByDefault: false },
  { id: 'code', title: 'Code', icon: 'code', visibleByDefault: false },
  { id: 'feedback', title: 'FeedBack', icon: 'feedback', visibleByDefault: false },
  { id: 'version', title: 'Version', icon: 'version', visibleByDefault: true }
];

export const visibleMeItems: MeItem[] = meItems.filter((item: MeItem) => item.visibleByDefault);
