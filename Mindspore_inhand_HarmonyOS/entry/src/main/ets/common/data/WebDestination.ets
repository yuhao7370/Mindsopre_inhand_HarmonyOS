import { AppStringKey } from '../i18n/AppStrings';

export const webPagePath: string = 'pages/WebPage';
export const harmonyPrivacyRawfile: string = 'privacy.html';

export const mindSporeBaseUrl: string = 'https://www.mindspore.cn';
export const mindSporeDocBaseUrl: string = `${mindSporeBaseUrl}/doc/note/zh-CN/master`;

export const userPrivacyRulesUrl: string = 'file:///android_asset/privacy.html';
export const collegeMainCloudUrl: string = `${mindSporeBaseUrl}/news/newschildren?id=354`;
export const collegeQuickTrainUrl: string =
  `${mindSporeBaseUrl}/tutorial/training/zh-CN/master/quick_start/quick_start.html`;
export const collegeQuickExecuteUrl: string =
  `${mindSporeBaseUrl}/tutorial/inference/zh-CN/master/multi_platform_inference.html`;
export const collegeQuickAppUrl: string =
  `${mindSporeBaseUrl}/tutorial/lite/zh-CN/master/quick_start/quick_start.html`;
export const collegeQuickVideoUrl: string =
  `${mindSporeBaseUrl}/tutorial/training/zh-CN/master/quick_start/quick_video.html`;
export const collegeMainFaqUrl: string = `${mindSporeBaseUrl}/doc/faq/zh-CN/master/index.html`;
export const collegeMainAskUrl: string = 'https://bbs.huaweicloud.com/forum/forum-1076-1.html';
export const intelligentPoetryUrl: string = `${mindSporeBaseUrl}/resources/tech/nlp/poetry`;

export const meApkUrl: string = 'https://download.mindspore.cn/model_zoo/official/lite/apk/mindmain.html';
export const meHelpUrl: string =
  'https://gitee.com/mindspore/mindspore/issues/new?issue%5Bassignee_id%5D=0&issue%5Bmilestone_id%5D=0';
export const meCodeUrl: string = 'https://gitee.com/mindspore/models/tree/master/official/lite';
export const meStarUrl: string = 'https://gitee.com/mindspore/mindspore';

export interface WebDestination {
  readonly titleKey: AppStringKey;
  readonly url: string;
  readonly localRawfile?: string;
}

interface WebDestinationMapping {
  readonly sourceUrl: string;
  readonly titleKey: AppStringKey;
  readonly localRawfile?: string;
}

const WEB_DESTINATION_MAPPINGS: WebDestinationMapping[] = [
  { sourceUrl: userPrivacyRulesUrl, titleKey: 'me_user_agreements', localRawfile: harmonyPrivacyRawfile },
  { sourceUrl: collegeMainCloudUrl, titleKey: 'college_cloud_title' },
  { sourceUrl: collegeQuickTrainUrl, titleKey: 'college_train_title' },
  { sourceUrl: collegeQuickExecuteUrl, titleKey: 'college_execute_title' },
  { sourceUrl: collegeQuickAppUrl, titleKey: 'college_app_title' },
  { sourceUrl: collegeQuickVideoUrl, titleKey: 'college_video_title' },
  { sourceUrl: collegeMainFaqUrl, titleKey: 'college_faq_title' },
  { sourceUrl: collegeMainAskUrl, titleKey: 'college_ask_title' },
  { sourceUrl: meStarUrl, titleKey: 'me_up_title' },
  { sourceUrl: mindSporeBaseUrl, titleKey: 'me_official_title' },
  { sourceUrl: meCodeUrl, titleKey: 'me_official_code_title' },
  { sourceUrl: meHelpUrl, titleKey: 'me_qa_title' },
  { sourceUrl: intelligentPoetryUrl, titleKey: 'title_intelligent_poetry' }
];

export function webUrlForRouteName(routeName: string): string | undefined {
  if (routeName === '/app/PrivacyPolicyActivity') {
    return userPrivacyRulesUrl;
  }
  if (routeName === '/app/IntelligentPoetryWritingActivity') {
    return intelligentPoetryUrl;
  }
  return undefined;
}

export function webDestinationForUrl(url: string, fallbackTitleKey: AppStringKey): WebDestination {
  const mapping = WEB_DESTINATION_MAPPINGS.find((item: WebDestinationMapping) => item.sourceUrl === url);
  if (!mapping) {
    return {
      titleKey: fallbackTitleKey,
      url: url
    };
  }
  return {
    titleKey: mapping.titleKey,
    url: mapping.localRawfile ? '' : mapping.sourceUrl,
    localRawfile: mapping.localRawfile
  };
}
