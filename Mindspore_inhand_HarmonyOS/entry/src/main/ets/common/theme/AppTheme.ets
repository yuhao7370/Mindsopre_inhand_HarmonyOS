export interface AppColorTheme {
  readonly primary: string;
  readonly primaryStart: string;
  readonly primaryEnd: string;
  readonly pageBackground: string;
  readonly cardBackground: string;
  readonly textPrimary: string;
  readonly textSecondary: string;
  readonly textMuted: string;
  readonly divider: string;
  readonly accent: string;
  readonly danger: string;
}

export interface AppSpacingTheme {
  readonly xs: number;
  readonly sm: number;
  readonly md: number;
  readonly lg: number;
  readonly xl: number;
  readonly page: number;
}

export interface AppRadiusTheme {
  readonly card: number;
  readonly button: number;
  readonly sheet: number;
}

export const AppColor: AppColorTheme = {
  primary: '#5E82FF',
  primaryStart: '#57C4DE',
  primaryEnd: '#6681FF',
  pageBackground: '#F7F8FA',
  cardBackground: '#FFFFFF',
  textPrimary: '#303133',
  textSecondary: '#606266',
  textMuted: '#A0A3AA',
  divider: '#E5E6EB',
  accent: '#6681FF',
  danger: '#F53F3F'
};

export const AppSpacing: AppSpacingTheme = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  page: 20
};

export const AppRadius: AppRadiusTheme = {
  card: 6,
  button: 6,
  sheet: 8
};
