export type AppStringKey =
  'empty' |
  'module_desc' |
  'EntryAbility_desc' |
  'EntryAbility_label' |
  'main_tab_title_one' |
  'main_tab_title_two' |
  'main_tab_title_three' |
  'experience_group_experience' |
  'experience_group_advanced' |
  'tab_experience_one' |
  'tab_speech_two' |
  'experience_head_title' |
  'experience_head_subtitle' |
  'title_splash_welcome' |
  'title_share' |
  'title_share_commend' |
  'splash_count_down' |
  'app_need_permission' |
  'app_permission_by_hand' |
  'splash_permission_retry' |
  'splash_permission_exit' |
  'college_head_title' |
  'college_head_subtitle' |
  'me_head_title' |
  'me_head_subtitle' |
  'mindspore_college_title' |
  'account_title' |
  'action_back' |
  'action_more' |
  'app_cancel' |
  'image_save_success' |
  'image_save_failed' |
  'qr_save_in_progress' |
  'confirm' |
  'dialog_btn_confirm' |
  'title_button_text_angle' |
  'title_pose_net' |
  'title_segmentation' |
  'title_image' |
  'title_gesture_recognition' |
  'title_scene_detection' |
  'title_dance' |
  'title_intelligent_poetry' |
  'title_text_extraction' |
  'title_texttranslation' |
  'title_object' |
  'title_object_camera' |
  'title_object_photo_detection' |
  'title_object_camera_detection' |
  'title_style_transfer' |
  'title_custom_model' |
  'title_college_faq' |
  'title_college_one_hour' |
  'title_college_forum' |
  'title_college_training' |
  'title_college_perform' |
  'title_college_broken_side' |
  'title_college_video' |
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
  'college_dialog_title' |
  'college_dialog_content' |
  'college_checked' |
  'college_adapter_view' |
  'me_share_title' |
  'me_my_qr_code' |
  'me_up_title' |
  'me_official_title' |
  'me_official_code_title' |
  'web_load_failed' |
  'web_retry' |
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
  'poem_save_poster' |
  'poem_share_poster' |
  'poem_save_success' |
  'poem_save_failed' |
  'poem_save_in_progress' |
  'poem_share_done' |
  'poem_share_failed' |
  'poem_share_in_progress' |
  'poem_ai_credit' |
  'dance_prepare_summary' |
  'dance_reference_video' |
  'dance_countdown' |
  'dance_reference_video_downloading' |
  'dance_reference_video_ready' |
  'dance_reference_video_failed' |
  'dance_start_demo' |
  'dance_start_live' |
  'dance_sampling' |
  'dance_sampling_done' |
  'dance_sampling_failed' |
  'dance_live_preview' |
  'dance_sampling_frames' |
  'dance_reset' |
  'dance_result_title' |
  'dance_score_prefix' |
  'dance_score_level_no_action' |
  'dance_score_level_no_point' |
  'dance_score_level_try_again' |
  'dance_score_level_warmup' |
  'dance_score_level_good' |
  'dance_score_level_great' |
  'dance_score_level_excellent' |
  'dance_score_level_perfect' |
  'dance_score_level_full' |
  'dance_platform_note' |
  'feature_runtime_inputs_title' |
  'feature_runtime_permissions_title' |
  'feature_runtime_result_title' |
  'feature_runtime_run' |
  'feature_runtime_run_translation' |
  'feature_runtime_status_idle' |
  'feature_runtime_status_preparing' |
  'feature_runtime_status_running' |
  'feature_runtime_live_camera_ready' |
  'feature_runtime_live_camera_failed' |
  'feature_runtime_live_camera_surface_missing' |
  'feature_runtime_live_frame_failed' |
  'feature_runtime_pending_adapter' |
  'feature_runtime_pose_detect_android' |
  'feature_runtime_pose_detect_success_android' |
  'feature_runtime_pose_detect_failed_android' |
  'feature_runtime_gesture_detect_android' |
  'feature_runtime_gesture_runner_unavailable' |
  'feature_runtime_gesture_done' |
  'feature_runtime_gesture_failed' |
  'gesture_label_one' |
  'gesture_label_two' |
  'gesture_label_three' |
  'gesture_label_four' |
  'gesture_label_five' |
  'gesture_label_six' |
  'gesture_label_seven' |
  'gesture_label_eight' |
  'gesture_label_nine' |
  'gesture_label_dislike' |
  'gesture_label_fist' |
  'gesture_label_thumb_up' |
  'gesture_label_heart' |
  'gesture_label_ok' |
  'gesture_label_other' |
  'feature_runtime_scene_runner_unavailable' |
  'feature_runtime_scene_done' |
  'feature_runtime_scene_failed' |
  'feature_runtime_unknown_route' |
  'feature_runtime_missing_input' |
  'feature_runtime_run_failed' |
  'feature_runtime_help' |
  'feature_runtime_help_image_classification' |
  'feature_runtime_help_object_photo' |
  'feature_runtime_help_object_camera' |
  'feature_runtime_help_pose_net' |
  'feature_runtime_help_image_segmentation' |
  'feature_runtime_help_scene_detection' |
  'feature_runtime_help_style_transfer' |
  'feature_runtime_custom_model_help' |
  'feature_runtime_custom_model_done' |
  'feature_runtime_custom_model_failed' |
  'feature_runtime_custom_model_model_required' |
  'feature_runtime_custom_model_image_required' |
  'feature_runtime_custom_model_select_model' |
  'feature_runtime_custom_model_select_photo' |
  'feature_runtime_custom_model_take_photo' |
  'feature_runtime_custom_model_execute' |
  'feature_runtime_custom_model_running_output' |
  'feature_runtime_custom_model_already_running' |
  'feature_runtime_custom_model_failure_output' |
  'feature_runtime_object_select_model' |
  'feature_runtime_custom_model_output_title' |
  'feature_runtime_custom_model_output_placeholder' |
  'feature_runtime_classification_runner_unavailable' |
  'feature_runtime_classification_done' |
  'feature_runtime_classification_failed' |
  'feature_runtime_live_classification_keep' |
  'feature_runtime_object_detection_done' |
  'feature_runtime_object_detection_failed' |
  'feature_runtime_style_transfer_done' |
  'feature_runtime_style_transfer_failed' |
  'feature_runtime_style_original_required' |
  'feature_runtime_style_choose_image' |
  'feature_runtime_style_album' |
  'feature_runtime_style_take_photo' |
  'feature_runtime_style_select_predict_model' |
  'feature_runtime_style_select_transfer_model' |
  'feature_runtime_style_predict_model_loaded' |
  'feature_runtime_style_predict_model_load_failed' |
  'feature_runtime_style_transfer_model_loaded' |
  'feature_runtime_style_transfer_model_load_failed' |
  'feature_runtime_text_recognition_done' |
  'feature_runtime_text_recognition_failed' |
  'feature_runtime_text_translation_done' |
  'feature_runtime_text_translation_offline_done' |
  'feature_runtime_text_translation_offline_unsupported' |
  'feature_runtime_text_translation_failed' |
  'feature_runtime_segmentation_done' |
  'feature_runtime_segmentation_failed' |
  'feature_runtime_segmentation_no_subject' |
  'feature_runtime_pose_done' |
  'feature_runtime_pose_failed' |
  'feature_runtime_permission_denied' |
  'feature_runtime_image_ready' |
  'feature_runtime_model_ready' |
  'feature_runtime_model_cache_failed' |
  'feature_runtime_model_incompatible' |
  'feature_runtime_text_ready' |
  'feature_runtime_pick_cancelled' |
  'feature_runtime_image_invalid' |
  'feature_runtime_text_placeholder' |
  'feature_runtime_text_translation_placeholder' |
  'feature_runtime_copy_text' |
  'feature_runtime_copy_done' |
  'feature_runtime_copy_failed' |
  'feature_runtime_save_image' |
  'feature_runtime_save_image_done' |
  'feature_runtime_save_image_failed' |
  'feature_runtime_save_image_missing' |
  'feature_runtime_style_recovery' |
  'feature_runtime_style_recovered' |
  'feature_runtime_go_live' |
  'feature_runtime_go_live_android_hms' |
  'feature_runtime_preview_title' |
  'feature_runtime_preview_image' |
  'feature_runtime_preview_background' |
  'feature_runtime_switch_camera' |
  'feature_runtime_preview_content' |
  'feature_runtime_preview_style' |
  'feature_runtime_preview_model' |
  'feature_runtime_style_presets_title' |
  'feature_runtime_style_custom' |
  'feature_runtime_portrait_background_presets' |
  'feature_runtime_portrait_background_custom' |
  'feature_runtime_portrait_background_1' |
  'feature_runtime_portrait_background_2' |
  'feature_runtime_portrait_background_3' |
  'feature_runtime_portrait_background_4' |
  'feature_runtime_portrait_background_5' |
  'feature_runtime_result_label' |
  'feature_runtime_result_score' |
  'feature_runtime_result_count' |
  'feature_runtime_result_scene_count' |
  'feature_runtime_result_scenes' |
  'feature_runtime_scene_overlay_count' |
  'feature_runtime_scene_overlay_scene' |
  'feature_runtime_scene_overlay_score' |
  'feature_runtime_result_top_detection' |
  'feature_runtime_result_detections' |
  'feature_runtime_result_lines' |
  'feature_runtime_result_text' |
  'feature_runtime_result_subjects' |
  'feature_runtime_result_details' |
  'feature_runtime_result_skeletons' |
  'feature_runtime_result_points' |
  'feature_runtime_result_similarity' |
  'feature_runtime_result_execution_time' |
  'feature_runtime_result_separator' |
  'feature_runtime_result_image' |
  'feature_runtime_result_model' |
  'feature_runtime_result_content_image' |
  'feature_runtime_result_style_image' |
  'feature_runtime_result_styled_image' |
  'feature_runtime_result_detection_overlay' |
  'feature_runtime_result_gesture_overlay' |
  'feature_runtime_result_segmentation_overlay' |
  'feature_runtime_result_pose_overlay' |
  'feature_runtime_result_pose_template' |
  'feature_runtime_result_output' |
  'feature_runtime_result_target_language' |
  'feature_runtime_result_translated_text' |
  'feature_runtime_result_foreground' |
  'feature_runtime_result_background' |
  'feature_runtime_result_background_replacement' |
  'feature_input_photo_android' |
  'feature_input_camera_android' |
  'feature_input_camera' |
  'feature_input_live_translation' |
  'feature_input_photo' |
  'feature_input_sample_image' |
  'feature_input_content_image' |
  'feature_input_style_image' |
  'feature_input_style_predict_model_file' |
  'feature_input_style_transfer_model_file' |
  'feature_input_model_file' |
  'feature_input_background_image' |
  'feature_input_text' |
  'feature_permission_camera' |
  'feature_permission_media' |
  'feature_permission_internet' |
  'permission_camera_reason' |
  'permission_media_reason' |
  'permission_save_image_reason' |
  'workflow_summary_classification' |
  'workflow_summary_object_photo' |
  'workflow_summary_object_camera' |
  'workflow_summary_style_transfer' |
  'workflow_summary_custom_model' |
  'workflow_summary_segmentation' |
  'workflow_summary_pose' |
  'workflow_summary_gesture' |
  'workflow_summary_gesture_still_android_prompt' |
  'workflow_summary_scene' |
  'workflow_summary_scene_still_android_prompt' |
  'workflow_summary_text_recognition' |
  'workflow_summary_text_recognition_android_prompt' |
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
  'experience_group_experience',
  'experience_group_advanced',
  'tab_experience_one',
  'tab_speech_two',
  'experience_head_title',
  'experience_head_subtitle',
  'title_splash_welcome',
  'title_share',
  'title_share_commend',
  'splash_count_down',
  'app_need_permission',
  'app_permission_by_hand',
  'splash_permission_retry',
  'splash_permission_exit',
  'college_head_title',
  'college_head_subtitle',
  'me_head_title',
  'me_head_subtitle',
  'mindspore_college_title',
  'account_title',
  'action_back',
  'action_more',
  'app_cancel',
  'image_save_success',
  'image_save_failed',
  'qr_save_in_progress',
  'confirm',
  'dialog_btn_confirm',
  'title_button_text_angle',
  'title_pose_net',
  'title_segmentation',
  'title_image',
  'title_gesture_recognition',
  'title_scene_detection',
  'title_dance',
  'title_intelligent_poetry',
  'title_text_extraction',
  'title_texttranslation',
  'title_object',
  'title_object_camera',
  'title_object_photo_detection',
  'title_object_camera_detection',
  'title_style_transfer',
  'title_custom_model',
  'title_college_faq',
  'title_college_one_hour',
  'title_college_forum',
  'title_college_training',
  'title_college_perform',
  'title_college_broken_side',
  'title_college_video',
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
  'college_dialog_title',
  'college_dialog_content',
  'college_checked',
  'college_adapter_view',
  'me_share_title',
  'me_my_qr_code',
  'me_up_title',
  'me_official_title',
  'me_official_code_title',
  'web_load_failed',
  'web_retry',
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
  'poem_save_poster',
  'poem_share_poster',
  'poem_save_success',
  'poem_save_failed',
  'poem_save_in_progress',
  'poem_share_done',
  'poem_share_failed',
  'poem_share_in_progress',
  'poem_ai_credit',
  'dance_prepare_summary',
  'dance_reference_video',
  'dance_countdown',
  'dance_reference_video_downloading',
  'dance_reference_video_ready',
  'dance_reference_video_failed',
  'dance_start_demo',
  'dance_start_live',
  'dance_sampling',
  'dance_sampling_done',
  'dance_sampling_failed',
  'dance_live_preview',
  'dance_sampling_frames',
  'dance_reset',
  'dance_result_title',
  'dance_score_prefix',
  'dance_score_level_no_action',
  'dance_score_level_no_point',
  'dance_score_level_try_again',
  'dance_score_level_warmup',
  'dance_score_level_good',
  'dance_score_level_great',
  'dance_score_level_excellent',
  'dance_score_level_perfect',
  'dance_score_level_full',
  'dance_platform_note',
  'feature_runtime_inputs_title',
  'feature_runtime_permissions_title',
  'feature_runtime_result_title',
  'feature_runtime_run',
  'feature_runtime_run_translation',
  'feature_runtime_status_idle',
  'feature_runtime_status_preparing',
  'feature_runtime_status_running',
  'feature_runtime_live_camera_ready',
  'feature_runtime_live_camera_failed',
  'feature_runtime_live_camera_surface_missing',
  'feature_runtime_live_frame_failed',
  'feature_runtime_pending_adapter',
  'feature_runtime_pose_detect_android',
  'feature_runtime_pose_detect_success_android',
  'feature_runtime_pose_detect_failed_android',
  'feature_runtime_gesture_detect_android',
  'feature_runtime_gesture_runner_unavailable',
  'feature_runtime_gesture_done',
  'feature_runtime_gesture_failed',
  'gesture_label_one',
  'gesture_label_two',
  'gesture_label_three',
  'gesture_label_four',
  'gesture_label_five',
  'gesture_label_six',
  'gesture_label_seven',
  'gesture_label_eight',
  'gesture_label_nine',
  'gesture_label_dislike',
  'gesture_label_fist',
  'gesture_label_thumb_up',
  'gesture_label_heart',
  'gesture_label_ok',
  'gesture_label_other',
  'feature_runtime_scene_runner_unavailable',
  'feature_runtime_scene_done',
  'feature_runtime_scene_failed',
  'feature_runtime_unknown_route',
  'feature_runtime_missing_input',
  'feature_runtime_run_failed',
  'feature_runtime_help',
  'feature_runtime_help_image_classification',
  'feature_runtime_help_object_photo',
  'feature_runtime_help_object_camera',
  'feature_runtime_help_pose_net',
  'feature_runtime_help_image_segmentation',
  'feature_runtime_help_scene_detection',
  'feature_runtime_help_style_transfer',
  'feature_runtime_custom_model_help',
  'feature_runtime_custom_model_done',
  'feature_runtime_custom_model_failed',
  'feature_runtime_custom_model_model_required',
  'feature_runtime_custom_model_image_required',
  'feature_runtime_custom_model_select_model',
  'feature_runtime_custom_model_select_photo',
  'feature_runtime_custom_model_take_photo',
  'feature_runtime_custom_model_execute',
  'feature_runtime_custom_model_running_output',
  'feature_runtime_custom_model_already_running',
  'feature_runtime_custom_model_failure_output',
  'feature_runtime_object_select_model',
  'feature_runtime_custom_model_output_title',
  'feature_runtime_custom_model_output_placeholder',
  'feature_runtime_classification_runner_unavailable',
  'feature_runtime_classification_done',
  'feature_runtime_classification_failed',
  'feature_runtime_live_classification_keep',
  'feature_runtime_object_detection_done',
  'feature_runtime_object_detection_failed',
  'feature_runtime_style_transfer_done',
  'feature_runtime_style_transfer_failed',
  'feature_runtime_style_original_required',
  'feature_runtime_style_choose_image',
  'feature_runtime_style_album',
  'feature_runtime_style_take_photo',
  'feature_runtime_style_select_predict_model',
  'feature_runtime_style_select_transfer_model',
  'feature_runtime_style_predict_model_loaded',
  'feature_runtime_style_predict_model_load_failed',
  'feature_runtime_style_transfer_model_loaded',
  'feature_runtime_style_transfer_model_load_failed',
  'feature_runtime_text_recognition_done',
  'feature_runtime_text_recognition_failed',
  'feature_runtime_text_translation_done',
  'feature_runtime_text_translation_offline_done',
  'feature_runtime_text_translation_offline_unsupported',
  'feature_runtime_text_translation_failed',
  'feature_runtime_segmentation_done',
  'feature_runtime_segmentation_failed',
  'feature_runtime_segmentation_no_subject',
  'feature_runtime_pose_done',
  'feature_runtime_pose_failed',
  'feature_runtime_permission_denied',
  'feature_runtime_image_ready',
  'feature_runtime_model_ready',
  'feature_runtime_model_cache_failed',
  'feature_runtime_model_incompatible',
  'feature_runtime_text_ready',
  'feature_runtime_pick_cancelled',
  'feature_runtime_image_invalid',
  'feature_runtime_text_placeholder',
  'feature_runtime_text_translation_placeholder',
  'feature_runtime_copy_text',
  'feature_runtime_copy_done',
  'feature_runtime_copy_failed',
  'feature_runtime_save_image',
  'feature_runtime_save_image_done',
  'feature_runtime_save_image_failed',
  'feature_runtime_save_image_missing',
  'feature_runtime_style_recovery',
  'feature_runtime_style_recovered',
  'feature_runtime_go_live',
  'feature_runtime_go_live_android_hms',
  'feature_runtime_preview_title',
  'feature_runtime_preview_image',
  'feature_runtime_preview_background',
  'feature_runtime_switch_camera',
  'feature_runtime_preview_content',
  'feature_runtime_preview_style',
  'feature_runtime_preview_model',
  'feature_runtime_style_presets_title',
  'feature_runtime_style_custom',
  'feature_runtime_portrait_background_presets',
  'feature_runtime_portrait_background_custom',
  'feature_runtime_portrait_background_1',
  'feature_runtime_portrait_background_2',
  'feature_runtime_portrait_background_3',
  'feature_runtime_portrait_background_4',
  'feature_runtime_portrait_background_5',
  'feature_runtime_result_label',
  'feature_runtime_result_score',
  'feature_runtime_result_count',
  'feature_runtime_result_scene_count',
  'feature_runtime_result_scenes',
  'feature_runtime_scene_overlay_count',
  'feature_runtime_scene_overlay_scene',
  'feature_runtime_scene_overlay_score',
  'feature_runtime_result_top_detection',
  'feature_runtime_result_detections',
  'feature_runtime_result_lines',
  'feature_runtime_result_text',
  'feature_runtime_result_subjects',
  'feature_runtime_result_details',
  'feature_runtime_result_skeletons',
  'feature_runtime_result_points',
  'feature_runtime_result_similarity',
  'feature_runtime_result_execution_time',
  'feature_runtime_result_separator',
  'feature_runtime_result_image',
  'feature_runtime_result_model',
  'feature_runtime_result_content_image',
  'feature_runtime_result_style_image',
  'feature_runtime_result_styled_image',
  'feature_runtime_result_detection_overlay',
  'feature_runtime_result_gesture_overlay',
  'feature_runtime_result_segmentation_overlay',
  'feature_runtime_result_pose_overlay',
  'feature_runtime_result_pose_template',
  'feature_runtime_result_output',
  'feature_runtime_result_target_language',
  'feature_runtime_result_translated_text',
  'feature_runtime_result_foreground',
  'feature_runtime_result_background',
  'feature_runtime_result_background_replacement',
  'feature_input_photo_android',
  'feature_input_camera_android',
  'feature_input_camera',
  'feature_input_live_translation',
  'feature_input_photo',
  'feature_input_sample_image',
  'feature_input_content_image',
  'feature_input_style_image',
  'feature_input_style_predict_model_file',
  'feature_input_style_transfer_model_file',
  'feature_input_model_file',
  'feature_input_background_image',
  'feature_input_text',
  'feature_permission_camera',
  'feature_permission_media',
  'feature_permission_internet',
  'permission_camera_reason',
  'permission_media_reason',
  'permission_save_image_reason',
  'workflow_summary_classification',
  'workflow_summary_object_photo',
  'workflow_summary_object_camera',
  'workflow_summary_style_transfer',
  'workflow_summary_custom_model',
  'workflow_summary_segmentation',
  'workflow_summary_pose',
  'workflow_summary_gesture',
  'workflow_summary_gesture_still_android_prompt',
  'workflow_summary_scene',
  'workflow_summary_scene_still_android_prompt',
  'workflow_summary_text_recognition',
  'workflow_summary_text_recognition_android_prompt',
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
    case 'experience_group_experience':
      return $r('app.string.experience_group_experience');
    case 'experience_group_advanced':
      return $r('app.string.experience_group_advanced');
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
    case 'app_need_permission':
      return $r('app.string.app_need_permission');
    case 'app_permission_by_hand':
      return $r('app.string.app_permission_by_hand');
    case 'splash_permission_retry':
      return $r('app.string.splash_permission_retry');
    case 'splash_permission_exit':
      return $r('app.string.splash_permission_exit');
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
    case 'action_back':
      return $r('app.string.action_back');
    case 'action_more':
      return $r('app.string.action_more');
    case 'app_cancel':
      return $r('app.string.app_cancel');
    case 'image_save_success':
      return $r('app.string.image_save_success');
    case 'image_save_failed':
      return $r('app.string.image_save_failed');
    case 'qr_save_in_progress':
      return $r('app.string.qr_save_in_progress');
    case 'confirm':
      return $r('app.string.confirm');
    case 'dialog_btn_confirm':
      return $r('app.string.dialog_btn_confirm');
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
    case 'title_scene_detection':
      return $r('app.string.title_scene_detection');
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
    case 'title_object_photo_detection':
      return $r('app.string.title_object_photo_detection');
    case 'title_object_camera_detection':
      return $r('app.string.title_object_camera_detection');
    case 'title_style_transfer':
      return $r('app.string.title_style_transfer');
    case 'title_custom_model':
      return $r('app.string.title_custom_model');
    case 'title_college_faq':
      return $r('app.string.title_college_faq');
    case 'title_college_one_hour':
      return $r('app.string.title_college_one_hour');
    case 'title_college_forum':
      return $r('app.string.title_college_forum');
    case 'title_college_training':
      return $r('app.string.title_college_training');
    case 'title_college_perform':
      return $r('app.string.title_college_perform');
    case 'title_college_broken_side':
      return $r('app.string.title_college_broken_side');
    case 'title_college_video':
      return $r('app.string.title_college_video');
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
    case 'college_dialog_title':
      return $r('app.string.college_dialog_title');
    case 'college_dialog_content':
      return $r('app.string.college_dialog_content');
    case 'college_checked':
      return $r('app.string.college_checked');
    case 'college_adapter_view':
      return $r('app.string.college_adapter_view');
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
    case 'web_load_failed':
      return $r('app.string.web_load_failed');
    case 'web_retry':
      return $r('app.string.web_retry');
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
    case 'poem_save_poster':
      return $r('app.string.poem_save_poster');
    case 'poem_share_poster':
      return $r('app.string.poem_share_poster');
    case 'poem_save_success':
      return $r('app.string.poem_save_success');
    case 'poem_save_failed':
      return $r('app.string.poem_save_failed');
    case 'poem_save_in_progress':
      return $r('app.string.poem_save_in_progress');
    case 'poem_share_done':
      return $r('app.string.poem_share_done');
    case 'poem_share_failed':
      return $r('app.string.poem_share_failed');
    case 'poem_share_in_progress':
      return $r('app.string.poem_share_in_progress');
    case 'poem_ai_credit':
      return $r('app.string.poem_ai_credit');
    case 'dance_prepare_summary':
      return $r('app.string.dance_prepare_summary');
    case 'dance_reference_video':
      return $r('app.string.dance_reference_video');
    case 'dance_countdown':
      return $r('app.string.dance_countdown');
    case 'dance_reference_video_downloading':
      return $r('app.string.dance_reference_video_downloading');
    case 'dance_reference_video_ready':
      return $r('app.string.dance_reference_video_ready');
    case 'dance_reference_video_failed':
      return $r('app.string.dance_reference_video_failed');
    case 'dance_start_demo':
      return $r('app.string.dance_start_demo');
    case 'dance_start_live':
      return $r('app.string.dance_start_live');
    case 'dance_sampling':
      return $r('app.string.dance_sampling');
    case 'dance_sampling_done':
      return $r('app.string.dance_sampling_done');
    case 'dance_sampling_failed':
      return $r('app.string.dance_sampling_failed');
    case 'dance_live_preview':
      return $r('app.string.dance_live_preview');
    case 'dance_sampling_frames':
      return $r('app.string.dance_sampling_frames');
    case 'dance_reset':
      return $r('app.string.dance_reset');
    case 'dance_result_title':
      return $r('app.string.dance_result_title');
    case 'dance_score_prefix':
      return $r('app.string.dance_score_prefix');
    case 'dance_score_level_no_action':
      return $r('app.string.dance_score_level_no_action');
    case 'dance_score_level_no_point':
      return $r('app.string.dance_score_level_no_point');
    case 'dance_score_level_try_again':
      return $r('app.string.dance_score_level_try_again');
    case 'dance_score_level_warmup':
      return $r('app.string.dance_score_level_warmup');
    case 'dance_score_level_good':
      return $r('app.string.dance_score_level_good');
    case 'dance_score_level_great':
      return $r('app.string.dance_score_level_great');
    case 'dance_score_level_excellent':
      return $r('app.string.dance_score_level_excellent');
    case 'dance_score_level_perfect':
      return $r('app.string.dance_score_level_perfect');
    case 'dance_score_level_full':
      return $r('app.string.dance_score_level_full');
    case 'dance_platform_note':
      return $r('app.string.dance_platform_note');
    case 'feature_runtime_inputs_title':
      return $r('app.string.feature_runtime_inputs_title');
    case 'feature_runtime_permissions_title':
      return $r('app.string.feature_runtime_permissions_title');
    case 'feature_runtime_result_title':
      return $r('app.string.feature_runtime_result_title');
    case 'feature_runtime_run':
      return $r('app.string.feature_runtime_run');
    case 'feature_runtime_run_translation':
      return $r('app.string.feature_runtime_run_translation');
    case 'feature_runtime_status_idle':
      return $r('app.string.feature_runtime_status_idle');
    case 'feature_runtime_status_preparing':
      return $r('app.string.feature_runtime_status_preparing');
    case 'feature_runtime_status_running':
      return $r('app.string.feature_runtime_status_running');
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
    case 'feature_runtime_pose_detect_android':
      return $r('app.string.feature_runtime_pose_detect_android');
    case 'feature_runtime_pose_detect_success_android':
      return $r('app.string.feature_runtime_pose_detect_success_android');
    case 'feature_runtime_pose_detect_failed_android':
      return $r('app.string.feature_runtime_pose_detect_failed_android');
    case 'feature_runtime_gesture_detect_android':
      return $r('app.string.feature_runtime_gesture_detect_android');
    case 'feature_runtime_gesture_runner_unavailable':
      return $r('app.string.feature_runtime_gesture_runner_unavailable');
    case 'feature_runtime_gesture_done':
      return $r('app.string.feature_runtime_gesture_done');
    case 'feature_runtime_gesture_failed':
      return $r('app.string.feature_runtime_gesture_failed');
    case 'gesture_label_one':
      return $r('app.string.gesture_label_one');
    case 'gesture_label_two':
      return $r('app.string.gesture_label_two');
    case 'gesture_label_three':
      return $r('app.string.gesture_label_three');
    case 'gesture_label_four':
      return $r('app.string.gesture_label_four');
    case 'gesture_label_five':
      return $r('app.string.gesture_label_five');
    case 'gesture_label_six':
      return $r('app.string.gesture_label_six');
    case 'gesture_label_seven':
      return $r('app.string.gesture_label_seven');
    case 'gesture_label_eight':
      return $r('app.string.gesture_label_eight');
    case 'gesture_label_nine':
      return $r('app.string.gesture_label_nine');
    case 'gesture_label_dislike':
      return $r('app.string.gesture_label_dislike');
    case 'gesture_label_fist':
      return $r('app.string.gesture_label_fist');
    case 'gesture_label_thumb_up':
      return $r('app.string.gesture_label_thumb_up');
    case 'gesture_label_heart':
      return $r('app.string.gesture_label_heart');
    case 'gesture_label_ok':
      return $r('app.string.gesture_label_ok');
    case 'gesture_label_other':
      return $r('app.string.gesture_label_other');
    case 'feature_runtime_scene_runner_unavailable':
      return $r('app.string.feature_runtime_scene_runner_unavailable');
    case 'feature_runtime_scene_done':
      return $r('app.string.feature_runtime_scene_done');
    case 'feature_runtime_scene_failed':
      return $r('app.string.feature_runtime_scene_failed');
    case 'feature_runtime_unknown_route':
      return $r('app.string.feature_runtime_unknown_route');
    case 'feature_runtime_missing_input':
      return $r('app.string.feature_runtime_missing_input');
    case 'feature_runtime_run_failed':
      return $r('app.string.feature_runtime_run_failed');
    case 'feature_runtime_help':
      return $r('app.string.feature_runtime_help');
    case 'feature_runtime_help_image_classification':
      return $r('app.string.feature_runtime_help_image_classification');
    case 'feature_runtime_help_object_photo':
      return $r('app.string.feature_runtime_help_object_photo');
    case 'feature_runtime_help_object_camera':
      return $r('app.string.feature_runtime_help_object_camera');
    case 'feature_runtime_help_pose_net':
      return $r('app.string.feature_runtime_help_pose_net');
    case 'feature_runtime_help_image_segmentation':
      return $r('app.string.feature_runtime_help_image_segmentation');
    case 'feature_runtime_help_scene_detection':
      return $r('app.string.feature_runtime_help_scene_detection');
    case 'feature_runtime_help_style_transfer':
      return $r('app.string.feature_runtime_help_style_transfer');
    case 'feature_runtime_custom_model_help':
      return $r('app.string.feature_runtime_custom_model_help');
    case 'feature_runtime_custom_model_done':
      return $r('app.string.feature_runtime_custom_model_done');
    case 'feature_runtime_custom_model_failed':
      return $r('app.string.feature_runtime_custom_model_failed');
    case 'feature_runtime_custom_model_model_required':
      return $r('app.string.feature_runtime_custom_model_model_required');
    case 'feature_runtime_custom_model_image_required':
      return $r('app.string.feature_runtime_custom_model_image_required');
    case 'feature_runtime_custom_model_select_model':
      return $r('app.string.feature_runtime_custom_model_select_model');
    case 'feature_runtime_custom_model_select_photo':
      return $r('app.string.feature_runtime_custom_model_select_photo');
    case 'feature_runtime_custom_model_take_photo':
      return $r('app.string.feature_runtime_custom_model_take_photo');
    case 'feature_runtime_custom_model_execute':
      return $r('app.string.feature_runtime_custom_model_execute');
    case 'feature_runtime_custom_model_running_output':
      return $r('app.string.feature_runtime_custom_model_running_output');
    case 'feature_runtime_custom_model_already_running':
      return $r('app.string.feature_runtime_custom_model_already_running');
    case 'feature_runtime_custom_model_failure_output':
      return $r('app.string.feature_runtime_custom_model_failure_output');
    case 'feature_runtime_object_select_model':
      return $r('app.string.feature_runtime_object_select_model');
    case 'feature_runtime_custom_model_output_title':
      return $r('app.string.feature_runtime_custom_model_output_title');
    case 'feature_runtime_custom_model_output_placeholder':
      return $r('app.string.feature_runtime_custom_model_output_placeholder');
    case 'feature_runtime_classification_runner_unavailable':
      return $r('app.string.feature_runtime_classification_runner_unavailable');
    case 'feature_runtime_classification_done':
      return $r('app.string.feature_runtime_classification_done');
    case 'feature_runtime_classification_failed':
      return $r('app.string.feature_runtime_classification_failed');
    case 'feature_runtime_live_classification_keep':
      return $r('app.string.feature_runtime_live_classification_keep');
    case 'feature_runtime_object_detection_done':
      return $r('app.string.feature_runtime_object_detection_done');
    case 'feature_runtime_object_detection_failed':
      return $r('app.string.feature_runtime_object_detection_failed');
    case 'feature_runtime_style_transfer_done':
      return $r('app.string.feature_runtime_style_transfer_done');
    case 'feature_runtime_style_transfer_failed':
      return $r('app.string.feature_runtime_style_transfer_failed');
    case 'feature_runtime_style_original_required':
      return $r('app.string.feature_runtime_style_original_required');
    case 'feature_runtime_style_choose_image':
      return $r('app.string.feature_runtime_style_choose_image');
    case 'feature_runtime_style_album':
      return $r('app.string.feature_runtime_style_album');
    case 'feature_runtime_style_take_photo':
      return $r('app.string.feature_runtime_style_take_photo');
    case 'feature_runtime_style_select_predict_model':
      return $r('app.string.feature_runtime_style_select_predict_model');
    case 'feature_runtime_style_select_transfer_model':
      return $r('app.string.feature_runtime_style_select_transfer_model');
    case 'feature_runtime_style_predict_model_loaded':
      return $r('app.string.feature_runtime_style_predict_model_loaded');
    case 'feature_runtime_style_predict_model_load_failed':
      return $r('app.string.feature_runtime_style_predict_model_load_failed');
    case 'feature_runtime_style_transfer_model_loaded':
      return $r('app.string.feature_runtime_style_transfer_model_loaded');
    case 'feature_runtime_style_transfer_model_load_failed':
      return $r('app.string.feature_runtime_style_transfer_model_load_failed');
    case 'feature_runtime_text_recognition_done':
      return $r('app.string.feature_runtime_text_recognition_done');
    case 'feature_runtime_text_recognition_failed':
      return $r('app.string.feature_runtime_text_recognition_failed');
    case 'feature_runtime_text_translation_done':
      return $r('app.string.feature_runtime_text_translation_done');
    case 'feature_runtime_text_translation_offline_done':
      return $r('app.string.feature_runtime_text_translation_offline_done');
    case 'feature_runtime_text_translation_offline_unsupported':
      return $r('app.string.feature_runtime_text_translation_offline_unsupported');
    case 'feature_runtime_text_translation_failed':
      return $r('app.string.feature_runtime_text_translation_failed');
    case 'feature_runtime_segmentation_done':
      return $r('app.string.feature_runtime_segmentation_done');
    case 'feature_runtime_segmentation_failed':
      return $r('app.string.feature_runtime_segmentation_failed');
    case 'feature_runtime_segmentation_no_subject':
      return $r('app.string.feature_runtime_segmentation_no_subject');
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
    case 'feature_runtime_model_incompatible':
      return $r('app.string.feature_runtime_model_incompatible');
    case 'feature_runtime_text_ready':
      return $r('app.string.feature_runtime_text_ready');
    case 'feature_runtime_pick_cancelled':
      return $r('app.string.feature_runtime_pick_cancelled');
    case 'feature_runtime_image_invalid':
      return $r('app.string.feature_runtime_image_invalid');
    case 'feature_runtime_text_placeholder':
      return $r('app.string.feature_runtime_text_placeholder');
    case 'feature_runtime_text_translation_placeholder':
      return $r('app.string.feature_runtime_text_translation_placeholder');
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
    case 'feature_runtime_style_recovery':
      return $r('app.string.feature_runtime_style_recovery');
    case 'feature_runtime_style_recovered':
      return $r('app.string.feature_runtime_style_recovered');
    case 'feature_runtime_go_live':
      return $r('app.string.feature_runtime_go_live');
    case 'feature_runtime_go_live_android_hms':
      return $r('app.string.feature_runtime_go_live_android_hms');
    case 'feature_runtime_preview_title':
      return $r('app.string.feature_runtime_preview_title');
    case 'feature_runtime_preview_image':
      return $r('app.string.feature_runtime_preview_image');
    case 'feature_runtime_preview_background':
      return $r('app.string.feature_runtime_preview_background');
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
    case 'feature_runtime_style_custom':
      return $r('app.string.feature_runtime_style_custom');
    case 'feature_runtime_portrait_background_presets':
      return $r('app.string.feature_runtime_portrait_background_presets');
    case 'feature_runtime_portrait_background_custom':
      return $r('app.string.feature_runtime_portrait_background_custom');
    case 'feature_runtime_portrait_background_1':
      return $r('app.string.feature_runtime_portrait_background_1');
    case 'feature_runtime_portrait_background_2':
      return $r('app.string.feature_runtime_portrait_background_2');
    case 'feature_runtime_portrait_background_3':
      return $r('app.string.feature_runtime_portrait_background_3');
    case 'feature_runtime_portrait_background_4':
      return $r('app.string.feature_runtime_portrait_background_4');
    case 'feature_runtime_portrait_background_5':
      return $r('app.string.feature_runtime_portrait_background_5');
    case 'feature_runtime_result_label':
      return $r('app.string.feature_runtime_result_label');
    case 'feature_runtime_result_score':
      return $r('app.string.feature_runtime_result_score');
    case 'feature_runtime_result_count':
      return $r('app.string.feature_runtime_result_count');
    case 'feature_runtime_result_scene_count':
      return $r('app.string.feature_runtime_result_scene_count');
    case 'feature_runtime_result_scenes':
      return $r('app.string.feature_runtime_result_scenes');
    case 'feature_runtime_scene_overlay_count':
      return $r('app.string.feature_runtime_scene_overlay_count');
    case 'feature_runtime_scene_overlay_scene':
      return $r('app.string.feature_runtime_scene_overlay_scene');
    case 'feature_runtime_scene_overlay_score':
      return $r('app.string.feature_runtime_scene_overlay_score');
    case 'feature_runtime_result_top_detection':
      return $r('app.string.feature_runtime_result_top_detection');
    case 'feature_runtime_result_detections':
      return $r('app.string.feature_runtime_result_detections');
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
    case 'feature_runtime_result_separator':
      return $r('app.string.feature_runtime_result_separator');
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
    case 'feature_runtime_result_gesture_overlay':
      return $r('app.string.feature_runtime_result_gesture_overlay');
    case 'feature_runtime_result_segmentation_overlay':
      return $r('app.string.feature_runtime_result_segmentation_overlay');
    case 'feature_runtime_result_pose_overlay':
      return $r('app.string.feature_runtime_result_pose_overlay');
    case 'feature_runtime_result_pose_template':
      return $r('app.string.feature_runtime_result_pose_template');
    case 'feature_runtime_result_output':
      return $r('app.string.feature_runtime_result_output');
    case 'feature_runtime_result_target_language':
      return $r('app.string.feature_runtime_result_target_language');
    case 'feature_runtime_result_translated_text':
      return $r('app.string.feature_runtime_result_translated_text');
    case 'feature_runtime_result_foreground':
      return $r('app.string.feature_runtime_result_foreground');
    case 'feature_runtime_result_background':
      return $r('app.string.feature_runtime_result_background');
    case 'feature_runtime_result_background_replacement':
      return $r('app.string.feature_runtime_result_background_replacement');
    case 'feature_input_photo_android':
      return $r('app.string.feature_input_photo_android');
    case 'feature_input_camera_android':
      return $r('app.string.feature_input_camera_android');
    case 'feature_input_camera':
      return $r('app.string.feature_input_camera');
    case 'feature_input_live_translation':
      return $r('app.string.feature_input_live_translation');
    case 'feature_input_photo':
      return $r('app.string.feature_input_photo');
    case 'feature_input_sample_image':
      return $r('app.string.feature_input_sample_image');
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
    case 'feature_input_background_image':
      return $r('app.string.feature_input_background_image');
    case 'feature_input_text':
      return $r('app.string.feature_input_text');
    case 'feature_permission_camera':
      return $r('app.string.feature_permission_camera');
    case 'feature_permission_media':
      return $r('app.string.feature_permission_media');
    case 'feature_permission_internet':
      return $r('app.string.feature_permission_internet');
    case 'permission_camera_reason':
      return $r('app.string.permission_camera_reason');
    case 'permission_media_reason':
      return $r('app.string.permission_media_reason');
    case 'permission_save_image_reason':
      return $r('app.string.permission_save_image_reason');
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
    case 'workflow_summary_gesture_still_android_prompt':
      return $r('app.string.workflow_summary_gesture_still_android_prompt');
    case 'workflow_summary_scene':
      return $r('app.string.workflow_summary_scene');
    case 'workflow_summary_scene_still_android_prompt':
      return $r('app.string.workflow_summary_scene_still_android_prompt');
    case 'workflow_summary_text_recognition':
      return $r('app.string.workflow_summary_text_recognition');
    case 'workflow_summary_text_recognition_android_prompt':
      return $r('app.string.workflow_summary_text_recognition_android_prompt');
    case 'workflow_summary_text_translation':
      return $r('app.string.workflow_summary_text_translation');
    case 'title_source':
      return $r('app.string.title_source');
    case 'empty':
    default:
      return '';
  }
}
