export type AppStringKey =
  'empty' |
  'module_desc' |
  'EntryAbility_desc' |
  'EntryAbility_label' |
  'main_tab_title_one' |
  'main_tab_title_two' |
  'main_tab_title_three' |
  'tab_experience_one' |
  'tab_speech_two' |
  'experience_head_title' |
  'experience_head_subtitle' |
  'title_splash_welcome' |
  'title_share' |
  'title_share_commend' |
  'splash_count_down' |
  'college_head_title' |
  'college_head_subtitle' |
  'me_head_title' |
  'me_head_subtitle' |
  'mindspore_college_title' |
  'account_title' |
  'feature_stub_title' |
  'feature_stub_message' |
  'action_back' |
  'confirm' |
  'title_button_text_angle' |
  'title_pose_net' |
  'title_segmentation' |
  'title_image' |
  'title_gesture_recognition' |
  'title_dance' |
  'title_intelligent_poetry' |
  'title_text_extraction' |
  'title_texttranslation' |
  'title_object' |
  'title_object_camera' |
  'title_style_transfer' |
  'title_custom_model' |
  'college_summary_title' |
  'college_cloud_title' |
  'college_quick_title' |
  'college_train_title' |
  'college_execute_title' |
  'college_app_title' |
  'college_video_title' |
  'college_faq_title' |
  'college_ask_title' |
  'college_light_title' |
  'college_dialog_content' |
  'college_checked' |
  'me_share_title' |
  'me_my_qr_code' |
  'me_up_title' |
  'me_official_title' |
  'me_official_code_title' |
  'me_qa_title' |
  'me_agree' |
  'me_disagree_and_exit' |
  'me_user_agreement' |
  'me_privacy' |
  'me_user_agreements' |
  'me_version_title' |
  'me_share_done' |
  'me_share_failed' |
  'qr_code_save_done' |
  'qr_code_save_failed' |
  'feature_runtime_inputs_title' |
  'feature_runtime_permissions_title' |
  'feature_runtime_result_title' |
  'feature_runtime_run' |
  'feature_runtime_status_idle' |
  'feature_runtime_status_preparing' |
  'feature_runtime_live_camera_ready' |
  'feature_runtime_live_camera_failed' |
  'feature_runtime_live_camera_surface_missing' |
  'feature_runtime_live_frame_failed' |
  'feature_runtime_pending_adapter' |
  'feature_runtime_gesture_unsupported' |
  'feature_runtime_gesture_done' |
  'feature_runtime_gesture_failed' |
  'feature_runtime_translation_unsupported' |
  'feature_runtime_unknown_route' |
  'feature_runtime_missing_input' |
  'feature_runtime_run_failed' |
  'feature_runtime_custom_model_done' |
  'feature_runtime_custom_model_failed' |
  'feature_runtime_classification_pending' |
  'feature_runtime_classification_done' |
  'feature_runtime_classification_failed' |
  'feature_runtime_object_detection_done' |
  'feature_runtime_object_detection_failed' |
  'feature_runtime_style_transfer_done' |
  'feature_runtime_style_transfer_failed' |
  'feature_runtime_text_recognition_done' |
  'feature_runtime_text_recognition_failed' |
  'feature_runtime_text_translation_done' |
  'feature_runtime_text_translation_failed' |
  'feature_runtime_segmentation_done' |
  'feature_runtime_segmentation_failed' |
  'feature_runtime_pose_done' |
  'feature_runtime_pose_failed' |
  'feature_runtime_permission_denied' |
  'feature_runtime_image_ready' |
  'feature_runtime_model_ready' |
  'feature_runtime_model_cache_failed' |
  'feature_runtime_text_ready' |
  'feature_runtime_pick_cancelled' |
  'feature_runtime_text_placeholder' |
  'feature_runtime_copy_text' |
  'feature_runtime_copy_done' |
  'feature_runtime_copy_failed' |
  'feature_runtime_save_image' |
  'feature_runtime_save_image_done' |
  'feature_runtime_save_image_failed' |
  'feature_runtime_save_image_missing' |
  'feature_runtime_preview_title' |
  'feature_runtime_preview_image' |
  'feature_runtime_switch_camera' |
  'feature_runtime_preview_content' |
  'feature_runtime_preview_style' |
  'feature_runtime_preview_model' |
  'feature_runtime_style_presets_title' |
  'feature_runtime_result_label' |
  'feature_runtime_result_score' |
  'feature_runtime_result_count' |
  'feature_runtime_result_top_detection' |
  'feature_runtime_result_lines' |
  'feature_runtime_result_text' |
  'feature_runtime_result_subjects' |
  'feature_runtime_result_details' |
  'feature_runtime_result_skeletons' |
  'feature_runtime_result_points' |
  'feature_runtime_result_similarity' |
  'feature_runtime_result_execution_time' |
  'feature_runtime_result_image' |
  'feature_runtime_result_model' |
  'feature_runtime_result_content_image' |
  'feature_runtime_result_style_image' |
  'feature_runtime_result_styled_image' |
  'feature_runtime_result_detection_overlay' |
  'feature_runtime_result_segmentation_overlay' |
  'feature_runtime_result_pose_overlay' |
  'feature_runtime_result_output' |
  'feature_runtime_result_target_language' |
  'feature_runtime_result_translated_text' |
  'feature_runtime_result_foreground' |
  'feature_input_camera' |
  'feature_input_photo' |
  'feature_input_content_image' |
  'feature_input_style_image' |
  'feature_input_style_predict_model_file' |
  'feature_input_style_transfer_model_file' |
  'feature_input_model_file' |
  'feature_input_text' |
  'feature_permission_camera' |
  'feature_permission_media' |
  'feature_permission_internet' |
  'workflow_summary_classification' |
  'workflow_summary_object_photo' |
  'workflow_summary_object_camera' |
  'workflow_summary_style_transfer' |
  'workflow_summary_custom_model' |
  'workflow_summary_segmentation' |
  'workflow_summary_pose' |
  'workflow_summary_gesture' |
  'workflow_summary_text_recognition' |
  'workflow_summary_text_translation' |
  'title_source';

const APP_STRING_KEYS: AppStringKey[] = [
  'empty',
  'module_desc',
  'EntryAbility_desc',
  'EntryAbility_label',
  'main_tab_title_one',
  'main_tab_title_two',
  'main_tab_title_three',
  'tab_experience_one',
  'tab_speech_two',
  'experience_head_title',
  'experience_head_subtitle',
  'title_splash_welcome',
  'title_share',
  'title_share_commend',
  'splash_count_down',
  'college_head_title',
  'college_head_subtitle',
  'me_head_title',
  'me_head_subtitle',
  'mindspore_college_title',
  'account_title',
  'feature_stub_title',
  'feature_stub_message',
  'action_back',
  'confirm',
  'title_button_text_angle',
  'title_pose_net',
  'title_segmentation',
  'title_image',
  'title_gesture_recognition',
  'title_dance',
  'title_intelligent_poetry',
  'title_text_extraction',
  'title_texttranslation',
  'title_object',
  'title_object_camera',
  'title_style_transfer',
  'title_custom_model',
  'college_summary_title',
  'college_cloud_title',
  'college_quick_title',
  'college_train_title',
  'college_execute_title',
  'college_app_title',
  'college_video_title',
  'college_faq_title',
  'college_ask_title',
  'college_light_title',
  'college_dialog_content',
  'college_checked',
  'me_share_title',
  'me_my_qr_code',
  'me_up_title',
  'me_official_title',
  'me_official_code_title',
  'me_qa_title',
  'me_agree',
  'me_disagree_and_exit',
  'me_user_agreement',
  'me_privacy',
  'me_user_agreements',
  'me_version_title',
  'me_share_done',
  'me_share_failed',
  'qr_code_save_done',
  'qr_code_save_failed',
  'feature_runtime_inputs_title',
  'feature_runtime_permissions_title',
  'feature_runtime_result_title',
  'feature_runtime_run',
  'feature_runtime_status_idle',
  'feature_runtime_status_preparing',
  'feature_runtime_live_camera_ready',
  'feature_runtime_live_camera_failed',
  'feature_runtime_live_camera_surface_missing',
  'feature_runtime_live_frame_failed',
  'feature_runtime_pending_adapter',
  'feature_runtime_gesture_unsupported',
  'feature_runtime_gesture_done',
  'feature_runtime_gesture_failed',
  'feature_runtime_translation_unsupported',
  'feature_runtime_unknown_route',
  'feature_runtime_missing_input',
  'feature_runtime_run_failed',
  'feature_runtime_custom_model_done',
  'feature_runtime_custom_model_failed',
  'feature_runtime_classification_pending',
  'feature_runtime_classification_done',
  'feature_runtime_classification_failed',
  'feature_runtime_object_detection_done',
  'feature_runtime_object_detection_failed',
  'feature_runtime_style_transfer_done',
  'feature_runtime_style_transfer_failed',
  'feature_runtime_text_recognition_done',
  'feature_runtime_text_recognition_failed',
  'feature_runtime_text_translation_done',
  'feature_runtime_text_translation_failed',
  'feature_runtime_segmentation_done',
  'feature_runtime_segmentation_failed',
  'feature_runtime_pose_done',
  'feature_runtime_pose_failed',
  'feature_runtime_permission_denied',
  'feature_runtime_image_ready',
  'feature_runtime_model_ready',
  'feature_runtime_model_cache_failed',
  'feature_runtime_text_ready',
  'feature_runtime_pick_cancelled',
  'feature_runtime_text_placeholder',
  'feature_runtime_copy_text',
  'feature_runtime_copy_done',
  'feature_runtime_copy_failed',
  'feature_runtime_save_image',
  'feature_runtime_save_image_done',
  'feature_runtime_save_image_failed',
  'feature_runtime_save_image_missing',
  'feature_runtime_preview_title',
  'feature_runtime_preview_image',
  'feature_runtime_switch_camera',
  'feature_runtime_preview_content',
  'feature_runtime_preview_style',
  'feature_runtime_preview_model',
  'feature_runtime_style_presets_title',
  'feature_runtime_result_label',
  'feature_runtime_result_score',
  'feature_runtime_result_count',
  'feature_runtime_result_top_detection',
  'feature_runtime_result_lines',
  'feature_runtime_result_text',
  'feature_runtime_result_subjects',
  'feature_runtime_result_details',
  'feature_runtime_result_skeletons',
  'feature_runtime_result_points',
  'feature_runtime_result_similarity',
  'feature_runtime_result_execution_time',
  'feature_runtime_result_image',
  'feature_runtime_result_model',
  'feature_runtime_result_content_image',
  'feature_runtime_result_style_image',
  'feature_runtime_result_styled_image',
  'feature_runtime_result_detection_overlay',
  'feature_runtime_result_segmentation_overlay',
  'feature_runtime_result_pose_overlay',
  'feature_runtime_result_output',
  'feature_runtime_result_target_language',
  'feature_runtime_result_translated_text',
  'feature_runtime_result_foreground',
  'feature_input_camera',
  'feature_input_photo',
  'feature_input_content_image',
  'feature_input_style_image',
  'feature_input_style_predict_model_file',
  'feature_input_style_transfer_model_file',
  'feature_input_model_file',
  'feature_input_text',
  'feature_permission_camera',
  'feature_permission_media',
  'feature_permission_internet',
  'workflow_summary_classification',
  'workflow_summary_object_photo',
  'workflow_summary_object_camera',
  'workflow_summary_style_transfer',
  'workflow_summary_custom_model',
  'workflow_summary_segmentation',
  'workflow_summary_pose',
  'workflow_summary_gesture',
  'workflow_summary_text_recognition',
  'workflow_summary_text_translation',
  'title_source'
];

export function hasAppStringKey(key: AppStringKey): boolean {
  return APP_STRING_KEYS.indexOf(key) >= 0;
}

export function appString(key: AppStringKey): ResourceStr {
  switch (key) {
    case 'module_desc':
      return $r('app.string.module_desc');
    case 'EntryAbility_desc':
      return $r('app.string.EntryAbility_desc');
    case 'EntryAbility_label':
      return $r('app.string.EntryAbility_label');
    case 'main_tab_title_one':
      return $r('app.string.main_tab_title_one');
    case 'main_tab_title_two':
      return $r('app.string.main_tab_title_two');
    case 'main_tab_title_three':
      return $r('app.string.main_tab_title_three');
    case 'tab_experience_one':
      return $r('app.string.tab_experience_one');
    case 'tab_speech_two':
      return $r('app.string.tab_speech_two');
    case 'experience_head_title':
      return $r('app.string.experience_head_title');
    case 'experience_head_subtitle':
      return $r('app.string.experience_head_subtitle');
    case 'title_splash_welcome':
      return $r('app.string.title_splash_welcome');
    case 'title_share':
      return $r('app.string.title_share');
    case 'title_share_commend':
      return $r('app.string.title_share_commend');
    case 'splash_count_down':
      return $r('app.string.splash_count_down');
    case 'college_head_title':
      return $r('app.string.college_head_title');
    case 'college_head_subtitle':
      return $r('app.string.college_head_subtitle');
    case 'me_head_title':
      return $r('app.string.me_head_title');
    case 'me_head_subtitle':
      return $r('app.string.me_head_subtitle');
    case 'mindspore_college_title':
      return $r('app.string.mindspore_college_title');
    case 'account_title':
      return $r('app.string.account_title');
    case 'feature_stub_title':
      return $r('app.string.feature_stub_title');
    case 'feature_stub_message':
      return $r('app.string.feature_stub_message');
    case 'action_back':
      return $r('app.string.action_back');
    case 'confirm':
      return $r('app.string.confirm');
    case 'title_button_text_angle':
      return $r('app.string.title_button_text_angle');
    case 'title_pose_net':
      return $r('app.string.title_pose_net');
    case 'title_segmentation':
      return $r('app.string.title_segmentation');
    case 'title_image':
      return $r('app.string.title_image');
    case 'title_gesture_recognition':
      return $r('app.string.title_gesture_recognition');
    case 'title_dance':
      return $r('app.string.title_dance');
    case 'title_intelligent_poetry':
      return $r('app.string.title_intelligent_poetry');
    case 'title_text_extraction':
      return $r('app.string.title_text_extraction');
    case 'title_texttranslation':
      return $r('app.string.title_texttranslation');
    case 'title_object':
      return $r('app.string.title_object');
    case 'title_object_camera':
      return $r('app.string.title_object_camera');
    case 'title_style_transfer':
      return $r('app.string.title_style_transfer');
    case 'title_custom_model':
      return $r('app.string.title_custom_model');
    case 'college_summary_title':
      return $r('app.string.college_summary_title');
    case 'college_cloud_title':
      return $r('app.string.college_cloud_title');
    case 'college_quick_title':
      return $r('app.string.college_quick_title');
    case 'college_train_title':
      return $r('app.string.college_train_title');
    case 'college_execute_title':
      return $r('app.string.college_execute_title');
    case 'college_app_title':
      return $r('app.string.college_app_title');
    case 'college_video_title':
      return $r('app.string.college_video_title');
    case 'college_faq_title':
      return $r('app.string.college_faq_title');
    case 'college_ask_title':
      return $r('app.string.college_ask_title');
    case 'college_light_title':
      return $r('app.string.college_light_title');
    case 'college_dialog_content':
      return $r('app.string.college_dialog_content');
    case 'college_checked':
      return $r('app.string.college_checked');
    case 'me_share_title':
      return $r('app.string.me_share_title');
    case 'me_my_qr_code':
      return $r('app.string.me_my_qr_code');
    case 'me_up_title':
      return $r('app.string.me_up_title');
    case 'me_official_title':
      return $r('app.string.me_official_title');
    case 'me_official_code_title':
      return $r('app.string.me_official_code_title');
    case 'me_qa_title':
      return $r('app.string.me_qa_title');
    case 'me_agree':
      return $r('app.string.me_agree');
    case 'me_disagree_and_exit':
      return $r('app.string.me_disagree_and_exit');
    case 'me_user_agreement':
      return $r('app.string.me_user_agreement');
    case 'me_privacy':
      return $r('app.string.me_privacy');
    case 'me_user_agreements':
      return $r('app.string.me_user_agreements');
    case 'me_version_title':
      return $r('app.string.me_version_title');
    case 'me_share_done':
      return $r('app.string.me_share_done');
    case 'me_share_failed':
      return $r('app.string.me_share_failed');
    case 'qr_code_save_done':
      return $r('app.string.qr_code_save_done');
    case 'qr_code_save_failed':
      return $r('app.string.qr_code_save_failed');
    case 'feature_runtime_inputs_title':
      return $r('app.string.feature_runtime_inputs_title');
    case 'feature_runtime_permissions_title':
      return $r('app.string.feature_runtime_permissions_title');
    case 'feature_runtime_result_title':
      return $r('app.string.feature_runtime_result_title');
    case 'feature_runtime_run':
      return $r('app.string.feature_runtime_run');
    case 'feature_runtime_status_idle':
      return $r('app.string.feature_runtime_status_idle');
    case 'feature_runtime_status_preparing':
      return $r('app.string.feature_runtime_status_preparing');
    case 'feature_runtime_live_camera_ready':
      return $r('app.string.feature_runtime_live_camera_ready');
    case 'feature_runtime_live_camera_failed':
      return $r('app.string.feature_runtime_live_camera_failed');
    case 'feature_runtime_live_camera_surface_missing':
      return $r('app.string.feature_runtime_live_camera_surface_missing');
    case 'feature_runtime_live_frame_failed':
      return $r('app.string.feature_runtime_live_frame_failed');
    case 'feature_runtime_pending_adapter':
      return $r('app.string.feature_runtime_pending_adapter');
    case 'feature_runtime_gesture_unsupported':
      return $r('app.string.feature_runtime_gesture_unsupported');
    case 'feature_runtime_gesture_done':
      return $r('app.string.feature_runtime_gesture_done');
    case 'feature_runtime_gesture_failed':
      return $r('app.string.feature_runtime_gesture_failed');
    case 'feature_runtime_translation_unsupported':
      return $r('app.string.feature_runtime_translation_unsupported');
    case 'feature_runtime_unknown_route':
      return $r('app.string.feature_runtime_unknown_route');
    case 'feature_runtime_missing_input':
      return $r('app.string.feature_runtime_missing_input');
    case 'feature_runtime_run_failed':
      return $r('app.string.feature_runtime_run_failed');
    case 'feature_runtime_custom_model_done':
      return $r('app.string.feature_runtime_custom_model_done');
    case 'feature_runtime_custom_model_failed':
      return $r('app.string.feature_runtime_custom_model_failed');
    case 'feature_runtime_classification_pending':
      return $r('app.string.feature_runtime_classification_pending');
    case 'feature_runtime_classification_done':
      return $r('app.string.feature_runtime_classification_done');
    case 'feature_runtime_classification_failed':
      return $r('app.string.feature_runtime_classification_failed');
    case 'feature_runtime_object_detection_done':
      return $r('app.string.feature_runtime_object_detection_done');
    case 'feature_runtime_object_detection_failed':
      return $r('app.string.feature_runtime_object_detection_failed');
    case 'feature_runtime_style_transfer_done':
      return $r('app.string.feature_runtime_style_transfer_done');
    case 'feature_runtime_style_transfer_failed':
      return $r('app.string.feature_runtime_style_transfer_failed');
    case 'feature_runtime_text_recognition_done':
      return $r('app.string.feature_runtime_text_recognition_done');
    case 'feature_runtime_text_recognition_failed':
      return $r('app.string.feature_runtime_text_recognition_failed');
    case 'feature_runtime_text_translation_done':
      return $r('app.string.feature_runtime_text_translation_done');
    case 'feature_runtime_text_translation_failed':
      return $r('app.string.feature_runtime_text_translation_failed');
    case 'feature_runtime_segmentation_done':
      return $r('app.string.feature_runtime_segmentation_done');
    case 'feature_runtime_segmentation_failed':
      return $r('app.string.feature_runtime_segmentation_failed');
    case 'feature_runtime_pose_done':
      return $r('app.string.feature_runtime_pose_done');
    case 'feature_runtime_pose_failed':
      return $r('app.string.feature_runtime_pose_failed');
    case 'feature_runtime_permission_denied':
      return $r('app.string.feature_runtime_permission_denied');
    case 'feature_runtime_image_ready':
      return $r('app.string.feature_runtime_image_ready');
    case 'feature_runtime_model_ready':
      return $r('app.string.feature_runtime_model_ready');
    case 'feature_runtime_model_cache_failed':
      return $r('app.string.feature_runtime_model_cache_failed');
    case 'feature_runtime_text_ready':
      return $r('app.string.feature_runtime_text_ready');
    case 'feature_runtime_pick_cancelled':
      return $r('app.string.feature_runtime_pick_cancelled');
    case 'feature_runtime_text_placeholder':
      return $r('app.string.feature_runtime_text_placeholder');
    case 'feature_runtime_copy_text':
      return $r('app.string.feature_runtime_copy_text');
    case 'feature_runtime_copy_done':
      return $r('app.string.feature_runtime_copy_done');
    case 'feature_runtime_copy_failed':
      return $r('app.string.feature_runtime_copy_failed');
    case 'feature_runtime_save_image':
      return $r('app.string.feature_runtime_save_image');
    case 'feature_runtime_save_image_done':
      return $r('app.string.feature_runtime_save_image_done');
    case 'feature_runtime_save_image_failed':
      return $r('app.string.feature_runtime_save_image_failed');
    case 'feature_runtime_save_image_missing':
      return $r('app.string.feature_runtime_save_image_missing');
    case 'feature_runtime_preview_title':
      return $r('app.string.feature_runtime_preview_title');
    case 'feature_runtime_preview_image':
      return $r('app.string.feature_runtime_preview_image');
    case 'feature_runtime_switch_camera':
      return $r('app.string.feature_runtime_switch_camera');
    case 'feature_runtime_preview_content':
      return $r('app.string.feature_runtime_preview_content');
    case 'feature_runtime_preview_style':
      return $r('app.string.feature_runtime_preview_style');
    case 'feature_runtime_preview_model':
      return $r('app.string.feature_runtime_preview_model');
    case 'feature_runtime_style_presets_title':
      return $r('app.string.feature_runtime_style_presets_title');
    case 'feature_runtime_result_label':
      return $r('app.string.feature_runtime_result_label');
    case 'feature_runtime_result_score':
      return $r('app.string.feature_runtime_result_score');
    case 'feature_runtime_result_count':
      return $r('app.string.feature_runtime_result_count');
    case 'feature_runtime_result_top_detection':
      return $r('app.string.feature_runtime_result_top_detection');
    case 'feature_runtime_result_lines':
      return $r('app.string.feature_runtime_result_lines');
    case 'feature_runtime_result_text':
      return $r('app.string.feature_runtime_result_text');
    case 'feature_runtime_result_subjects':
      return $r('app.string.feature_runtime_result_subjects');
    case 'feature_runtime_result_details':
      return $r('app.string.feature_runtime_result_details');
    case 'feature_runtime_result_skeletons':
      return $r('app.string.feature_runtime_result_skeletons');
    case 'feature_runtime_result_points':
      return $r('app.string.feature_runtime_result_points');
    case 'feature_runtime_result_similarity':
      return $r('app.string.feature_runtime_result_similarity');
    case 'feature_runtime_result_execution_time':
      return $r('app.string.feature_runtime_result_execution_time');
    case 'feature_runtime_result_image':
      return $r('app.string.feature_runtime_result_image');
    case 'feature_runtime_result_model':
      return $r('app.string.feature_runtime_result_model');
    case 'feature_runtime_result_content_image':
      return $r('app.string.feature_runtime_result_content_image');
    case 'feature_runtime_result_style_image':
      return $r('app.string.feature_runtime_result_style_image');
    case 'feature_runtime_result_styled_image':
      return $r('app.string.feature_runtime_result_styled_image');
    case 'feature_runtime_result_detection_overlay':
      return $r('app.string.feature_runtime_result_detection_overlay');
    case 'feature_runtime_result_segmentation_overlay':
      return $r('app.string.feature_runtime_result_segmentation_overlay');
    case 'feature_runtime_result_pose_overlay':
      return $r('app.string.feature_runtime_result_pose_overlay');
    case 'feature_runtime_result_output':
      return $r('app.string.feature_runtime_result_output');
    case 'feature_runtime_result_target_language':
      return $r('app.string.feature_runtime_result_target_language');
    case 'feature_runtime_result_translated_text':
      return $r('app.string.feature_runtime_result_translated_text');
    case 'feature_runtime_result_foreground':
      return $r('app.string.feature_runtime_result_foreground');
    case 'feature_input_camera':
      return $r('app.string.feature_input_camera');
    case 'feature_input_photo':
      return $r('app.string.feature_input_photo');
    case 'feature_input_content_image':
      return $r('app.string.feature_input_content_image');
    case 'feature_input_style_image':
      return $r('app.string.feature_input_style_image');
    case 'feature_input_style_predict_model_file':
      return $r('app.string.feature_input_style_predict_model_file');
    case 'feature_input_style_transfer_model_file':
      return $r('app.string.feature_input_style_transfer_model_file');
    case 'feature_input_model_file':
      return $r('app.string.feature_input_model_file');
    case 'feature_input_text':
      return $r('app.string.feature_input_text');
    case 'feature_permission_camera':
      return $r('app.string.feature_permission_camera');
    case 'feature_permission_media':
      return $r('app.string.feature_permission_media');
    case 'feature_permission_internet':
      return $r('app.string.feature_permission_internet');
    case 'workflow_summary_classification':
      return $r('app.string.workflow_summary_classification');
    case 'workflow_summary_object_photo':
      return $r('app.string.workflow_summary_object_photo');
    case 'workflow_summary_object_camera':
      return $r('app.string.workflow_summary_object_camera');
    case 'workflow_summary_style_transfer':
      return $r('app.string.workflow_summary_style_transfer');
    case 'workflow_summary_custom_model':
      return $r('app.string.workflow_summary_custom_model');
    case 'workflow_summary_segmentation':
      return $r('app.string.workflow_summary_segmentation');
    case 'workflow_summary_pose':
      return $r('app.string.workflow_summary_pose');
    case 'workflow_summary_gesture':
      return $r('app.string.workflow_summary_gesture');
    case 'workflow_summary_text_recognition':
      return $r('app.string.workflow_summary_text_recognition');
    case 'workflow_summary_text_translation':
      return $r('app.string.workflow_summary_text_translation');
    case 'title_source':
      return $r('app.string.title_source');
    case 'empty':
    default:
      return '';
  }
}
