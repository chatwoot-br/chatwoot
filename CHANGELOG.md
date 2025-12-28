# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v4.9.1] - 2025-12-22

### Fixed

- Improve handling of empty custom attributes list in settings (#13127)
- Prevent invalid attachments from blocking text paste (#13135)
- Add Linear integration for the Startup plan (#13136)

## [4.9.0] - 2025-12-19

### Added

- Voice Channel support (#11602)
- TikTok channel integration (#12741)
- Year in review feature (#13078)
- Voice conference API for Enterprise (#13064)
- Plain-text editor for non-rich content channels (#13058)
- Backend changes for WhatsApp CSAT template (#12984)
- AI credit topup flow for Stripe (#12988)
- Support for shared post and story attachment types in Instagram messages (#12997)
- Pinia support and relocated store factory (#12854)
- Captain instrumentation (#12949)
- Outbound voice call essentials (#12782)
- Support for Langfuse LLM Tracing via OTEL (#12905)
- Retry loadWithRetry composable (#12873)
- Custom attribute page redesign (#13087)
- Conversation workflow backend changes (#13070)
- Attachment paste enabled in new conversation modal (#13082)

### Changed

- Standardize rich editor across all channels (#12600)
- Strip unsupported signature formatting by channel (#13046)
- Clean up reply box component (#13060)
- Pagination with compact number formatting and pluralization (#12921)
- Custom RuboCop cop to enforce one class per file (#12947)
- Migrate legacy features to Ruby LLM (#12994)
- Migrate editor to Ruby LLM (#12961)
- Migrate Ruby LLM Captain (#12981)

### Fixed

- Validate blob before attaching it to a record (#13115)
- Skip orphaned inbox members in widget API endpoint (#13054)
- Contact form buttons cut off on mobile web (#13099)
- Prioritize SDK `enableFileUpload` flag when explicitly set (#13091)
- Share modal not working in year-in-review (#13079)
- Captain template message conflict (#13048)
- Preserve double newlines in text-based messaging channels (#13055)
- Handle rich message signatures and attachment overflow (#13045)
- Preserve multiple newlines with whitespace in text-based messaging channels (#13044)
- Prevent SLA deletion timeouts by moving to async job (#12944)
- Strip unsupported markdown formatting from canned responses (#13028)
- Preserve newlines and formatting in Twilio WhatsApp messages (#13022)
- Hide Linear card when not enabled (#12918)
- Stream attachment handling in workers (#12870)
- Ruby LLM version conflicts with AI agents (#13011)
- Hardcoded 500 in AI API error response (#13005)
- Handle Instagram API error codes properly in message processing (#13002)
- Filter out unsupported ephemeral message attachments (#13003)
- Handle missing AccountUser in inbox_member API (#12993)
- Reduce unnecessary label suggestion API calls (#12978)
- Enable reply editor for API channels with templates (#12973)
- Resolve z-index issue in assistant switcher (#12969, #12940)
- Handle string return values in MailPresenter#from method (#12966)
- Disable SSL verification for LINE webhooks in development (#12960)
- Show WhatsApp templates only for inboxes with templates (#12965)
- Prevent WhatsApp campaign duplicate messages by updating status immediately (#12955)
- Invalid language tag in heatmap component in reports page (#12952)
- Add presence validation for account name (#12636)
- Switch label suggestions to gpt-5-nano (#12945)
- Reactive assistantId issue in Captain Inbox after route changes (#12939)
- Widget shows 'away' on initial load despite agents being online (#12869)
- Change messages.source_id to text column (#12908)

## [4.8.0] - 2025-11-18

### Added

- APIs to assign agents/bots as assignee in conversations (#12836)
- Amazon SES inbound email support (#12893)
- Companies page and API endpoint with pagination and search (#12842, #12840)
- Control allowed login methods via Super Admin (#12892)
- Customizable webhook timeout configuration (#12777)
- Configurable attachment upload limit (#12835)
- Assignment service v2 (#12320)
- Webhook name support (#12641)
- Querying reporting events via the API (#12832)
- Month range selection in overview reports (#12701)
- Bulk delete for contacts (#12778)
- Company auto-association for contacts (#12711)
- Company backfill migration for existing contacts (#12657)
- OpenSearch enabled on paid plans automatically (#12770)
- Bulk actions for contacts (#12763)
- Always process email content (#12734)
- Template types components (#12714)
- Changelog card components (#12673)
- Website content fetching service for Captain Assistant persona (Enterprise) (#12732)
- Single query for reporting event stats (#12664)

### Changed

- Hide email forwarding address if INBOUND_EMAIL_DOMAIN is not configured (#12768)
- Update Captain navigation structure (#12761)
- Improve captain layout (#12820)
- Strategy pattern for mailbox conversation finding (#12766)
- Speed up Docker builds (#12859)
- Enforce custom role permissions on conversation access (#12583)
- Migrate mailers from worker to jobs (#12331)

### Fixed

- Change contact_inboxes.source_id to text column (#12882)
- Revert annotaterb migration due to persistent annotation errors (#12881)
- Brand installation name not showing (#12861)
- Respect status parameter when creating articles via API (#12846)
- Label tags for contactable inboxes (#12838)
- Use contact_id instead of sender_id for Instagram message locks (#12841)
- Hide PDF citations in Captain FAQ responses (#12839)
- Issue with processing variables in outgoing email content (#12799)
- Handle login when there are no accounts (#12816)
- Remove the same account validation for WhatsApp channels (#12811)
- Add empty line before signature in compose conversation editor (#12702)
- Video bubble click and play issue (#12764)
- Gate Sidekiq dequeue logger behind env (#12790)
- Avoid introducing new attributes in search (#12791)
- Optimize Message search_data to prevent OpenSearch field explosion (#12786)
- Run Captain v2 outside the transaction (#12756)
- Exclude authentication templates from WhatsApp template selection (#12753)
- Captain response builder not getting triggered (#12729)
- Timezone offset reports broken by DST transition (#12747)
- Extend phone number normalization to Twilio WhatsApp (#12655)
- Parameterize agent name (#12709)

## [4.7.0] - 2025-10-15

### Added

- Support for HTML emails in outgoing messages (#12662)
- Overview heatmap improvements (#12359)
- Secure external credentials with database encryption (#12648)
- Open conversation when agent bot webhook fails (#12379)
- Company model and API with tests (#12548)
- Relay state for SAML SSO (#12597)
- UI for custom tools (#12585)
- Captain custom HTTP tools (Enterprise) (#12584)
- WhatsApp health monitoring and self-service registration completion (#12556)
- Quoted email thread in reply (#12545)
- Log push notification error (#12543)
- Form validation message for password input (#11705)
- Password visibility toggle to form input (#12524)
- Resolved contacts as base relation for filtering (#12520)
- Brazil phone number normalization as generic service (#12492)
- Clean up email configuration for from and reply to emails (#12453)
- UI to manage web widget allowed domains (#12495)
- SAML feedback changes (#12511)
- Separate indexing with the search feature (#12503)
- Load reply-to messages dynamically when not present in message list (#10024)
- Lock to single thread settings for Telegram (#12367)
- Support for grouped file uploads in Slack (#12454)
- Auto confirm user email when super admin makes changes (#12418)
- Creating contact notes (#12494)
- SP initiated SAML (#12447)
- Optional phone_number_id parameter to media retrieval API (#11823)
- Contact search by phone number (#10386)
- `SKIP_INCOMING_BCC_PROCESSING` as internal config (#12484)
- Superlong debounce condition for meta endpoint (#12486)
- Accept file attachment in LINE channel (#12321)
- Captain animating SVGs (#12448)

### Changed

- Include 11:59 PM slot in business hours display (#12610)
- Increase custom filter limit from 50 to 1000 per user (#12603)
- UI improvement in auth screens (#12573)
- Adjust debounce timeouts for conversation stats fetch (#12609)
- Improve Captain conversation handling (#12599)
- Update Guyana's country dial code from +595 to +592 (#12510)

### Fixed

- Duplicate contacts creating for Argentina numbers (#11173)
- Handle video file types in Slack file shares (#12630)
- Correct null matching logic in filters (#12627)
- Optimize message reindexing to reduce Sidekiq job creation (#12618)
- I18n::MissingInterpolationArgument for assignee activity messages (#12617)
- Normalize URLs with spaces in WhatsApp template parameters (#12594)
- Update max_turns config (#12604)
- Display proper conversation ID with click-to-open in SLA reports (#12570)
- Rendering on email without HTML content (#12561)
- Optimize Slack channel fetching to avoid rate limiting issues (#12542)
- Auto resolution flaky spec (#11964)
- Contact optimization fixes (#12016)
- Ensure message is always present in `conversation_created` webhook for WhatsApp attachment messages (#12507)
- Remove unnecessary scroll bars from filter dropdown (#12515)
- Inbox delete confirmation fails due to whitespace (#12498)
- Session controller to not generate auth tokens before MFA verification (#12487)
- Use account locale when generating PDF FAQs (#12491)
- Ensure messages go to correct conversation when receiving multiple users in one LINE webhook (#12322)

## [4.6.0] - 2025-09-19

### Added

- Single audio playback functionality across components (#12226)
- Frontend support for MFA (#12372)
- MFA support (#12290)
- `media_name` support for WhatsApp templates document files (#12462)
- Searching Captain responses (#12463)
- Support for labels in automations (#11658)
- Detaching help center widget (#12459)
- Invite handling for SAML enabled account (#12439)
- Allowed domains for web widget (#12450)
- Retry failed messages within 24h (#12436)
- Support for customizing expiry of widget token (#12446)
- Remove SAML from premium feature list (#12443)
- Update users on SAML setup and destroy (#12346)
- SAML UI (#12345)
- Agent capacity policy Create/Edit pages (#12424)
- Agent capacity policy index page with CRUD actions (#12409)
- SAML authentication controllers (#12319)
- Agent assignment policy Create/Edit pages (#12400)
- Agent assignment policy index page with CRUD actions (#12373)
- Agent language settings (#11222)
- `INSTALLATION_NAME` to global config (#12376)
- Incoming voice calls (Enterprise) (#12361)
- SAML model and controller (#12289)
- AssignmentCard with story for agent UI (#12360)
- Frontend changes for Captain PDF support for FAQ generation (#12115)
- Update Inbox/Team creation UI (#12305)
- Filter contact based on labels (#12343)
- Display notification count in sidebar inbox item (#12324)
- Display banner and handoff for bot-managed chats (#12292)
- Run assignment every 15 minutes (#12334)
- Twilio content templates (#12277)
- Widget articles based on correct locale (#12316)
- Advanced, performant message search (Enterprise) (#12193)
- Backend changes for Captain PDF support for FAQ generation (#12113)
- Ops task to purge orphan conversations (#12279)
- QR codes for WhatsApp, Messenger, and Telegram on inbox finish page (#12257)
- PostHog analytics setup (#12291)
- Agent capacity controllers (#12200)
- Channel-specific file upload rules and size limits (#12237)
- Config for embedding model (#12120)
- Backend support for Twilio content templates (#12272)
- Liquid template support for WhatsApp template parameters (#12227)
- Improved voice call creation flow (Enterprise) (#12268)

### Changed

- Assignment policy improvements (#12429)
- Flexible WhatsApp onboarding (Manual + Embedded Signup) options (#12344)
- Update Tehran timezone from GMT+04:30 to GMT+03:30 (#12427)
- Remove unused Telegram bot model (#12417)
- Upgrade Facebook API version from v17.0 to v18.0 (#12384)
- Consolidate WhatsApp template components and improve naming (#12299)
- Convert availability slots to local timezone (#12273)
- Migrate availability mixins to composable and helper (#11596)
- Refactor UTM params to stay compliant with standards (#12312)
- Replace copilot input with auto-expanding textarea (#12296)
- Default file limits for private notes and reset attachment on mode switch (#12310)

### Fixed

- Use case sensitive filter for phone_numbers (#12470)
- Prevent inbox settings freeze on empty `welcome_tagline` (#12440)
- Handle empty string for CAPTAIN_OPEN_AI_ENDPOINT config (#12435)
- Display embedding model config in super admin UI (#12303)
- Search rake task causing Rails boot error (#12416)
- `display_id` to `id` mapping not handled (#12426)
- Pre-purge heavy associations before destroy to prevent timeout (#12408)
- Assignment V2 controller fix (#12415)
- Use translations for name when sending emails (#12411)
- Add URL validation and rate limiting for contact avatar sync (#11979)
- Use .find_by instead .where().first (#12402)
- Editor toggle button not showing the correct active mode (#12350)
- Resolution count does not have account scope (#12370)
- Add scrollbar to search bar dropdown (#12362)
- Plain text with valid HTML not rendering (#12369)
- TypeError: Cannot read properties of null (reading 'config') (#12356)
- Wrong resolution count in timeseries reports (#12261)
- UI issues with Instagram channel (#12355)
- Prevent `[object Object]` when copying custom attributes (#12323)
- Memory leak in vue-letter from fallback text content (#12212)
- Prevent filter text from being cutoff in superadmin console (#12238)
- Use dynamic installation name in vueapp.html.erb (#11799)
- cwctl version to handle the upgrade loop (#12232)

## [4.5.2] - 2025-08-20

### Changed

- Sync model annotations with current schema (#12245)

### Reverted

- SDK changes to ignore messages from a different origin and sanitize URLs (#12248)

## [4.5.1] - 2025-08-20

### Added

- Voice call button on Contacts with inbox picker (#12218)
- Assignment policies controllers with jbuilder views (#12199)

### Fixed

- Skip AddFeatureCitationToAssistantConfig migration on OSS (#12244)
- Prevent reopening a resolved conversation (#11168)

## [4.5.0] - 2025-08-18

### Added

- Full change log to profile (#12215)
- Scenario agents and runner (#11944)
- Bulgarian (bg) language (#12189)
- Automation rule event conversation resolved (#9669)
- WhatsApp enhanced templates front end changes (#12117)
- WhatsApp profile for contact name resolution (#12123)
- Migration files for assignment v2 (#12147)
- Route to list accounts that belongs to a platform_app (#12140)
- Enhanced WhatsApp template support with media headers (#11997)
- Citations option to edit assistant form (#12151)
- `feature_citation` toggle for Captain assistants (#12052)
- Support to embedded WhatsApp coexistence method (#12108)
- More tools for Captain (#12116)
- Reauth flow for WhatsApp embedded signup (#11940)
- Twilio WhatsApp `ProfileName` integration for contact name resolution (#12122)
- New tab and copy link to conversation context menu (#12089)
- Support for viewing status of SSL in custom domains (Cloud) (#12011)
- New Scenarios page (#11975)
- Support for inbox variables (#11952)
- Captain endpoint config in legacy OpenAI base service (#12060)
- References header to reply emails (#11719)
- Config for OpenAI endpoint (#12051)
- Skip inbox filter if the user has access to all inboxes (#12043)
- Remove subscription on WhatsApp inbox delete (#11977)
- CRM v2 feature flag for CRM changes (#12014)
- Don't add inbox condition for admins in search (#12028)
- Manual WhatsApp templates sync with UI (#12007)
- Ability to set up only web/worker deployments for Linux (#12004)
- Exclude account settings page from upgrade paywall (#11998)
- Scenario tools (#11908)
- Support for multiple attachments in Slack (#11958)
- New GuardRails and Response Guidelines edit page (#11932)

### Changed

- Contact empty state data (#12207)
- Improvements in scenarios (#12098)
- Optimize contact page for smaller displays (#12183)
- Handle WebPush rate limiting in push notification service (#12184)
- UI improvements to compose new conversation form (#12173)
- Replace Thumbnail with Avatar component (#12119, #12112, #12152)
- WhatsApp template message error handling for invalid templates (#12157)
- Improve portal settings validation and error handling (#12134)
- Update inbox view to perform better with sidebar on inbox views (#12077)
- Update filter input UI design (#12081)
- Improve layout styles (#12025)
- Migrate to next Switch component (#12005)
- Automate SSL with Cloudflare (#12021)
- Add sidekiq_alive gem for health check endpoint (#12008)

### Fixed

- Switch to Datadog v2 gem (#12214)
- SDK to ignore messages from a different origin and sanitize URLs (#8879)
- Setup webhook for create and update should be done after db commit (#12176)
- Incorrect first response time for reopened conversations (#12058)
- Handle nil `processed_params` for WhatsApp templates without params (#12177)
- Improve WhatsApp template message error handling (#12168)
- Grid layout for color picker (#12166)
- RTL issues in new conversation form (#12163)
- Resolve mutex conflicts in Instagram webhook specs (#12154)
- Handle active storage preview error for password protected PDFs (#11888)
- Error shouldn't halt the campaign for entire audience (#11980)
- Date filter breaking in custom view (#12132)
- Fix overlap issue with filter dropdown (#12133)
- Notifications duplicate query and add composite index (#12110)
- Styles issues with conversation card (#12107)
- Installation name not showing (#12096)
- Use WhatsApp profile name for contacts created via Twilio (#12105)
- Disable automations on auto-reply emails (#12101)
- Overflow issue with conversation card (#12104)
- Skip HookJob for inactive or irrelevant hooks (#12093)
- Conditionally fetch limits and assistants for enterprise/cloud (#12099)
- Populate meta field for WhatsApp shared contacts (#12097)
- Disable IMAP inboxes that requires authorization (#12092)
- Outer heredocs variable expansion during cwctl upgrade (#12086)
- Handle bounced email (#11873)
- Footer in ssl_instructions email (#12076)
- `CAPTAIN_OPEN_AI_ENDPOINT` presence not checked correctly (#12069)
- Custom branch upgrade via cwctl (#12070)
- Creates contact when Instagram returns `No matching Instagram user` (#11496)
- Add delay to Instagram/Messenger echo events to prevent duplicate messages (#12032)
- Code component style issue (#12022)
- Circle CI bundle audit (#12019)
- cwctl web/worker conversion (#12006)
- Bubble color for outgoing email (#12003)
- Fetch all Facebook pages during inbox creation (#11956)

## [4.4.0] - 2025-07-16

### Added

- Private note action to automations (#11926)
- WhatsApp campaigns (#11910)
- WhatsApp embedded signup (#11612)
- Response guidelines and guardrails field (#11911)
- Captain Scenario model and API (#11907)
- New Assistants Edit Page (#11920)
- Support for images in Captain (#11850)
- Captain settings header component (#11912)
- Customizable welcome text, availability messages, and UI toggles (#11891)
- Translate Priority and Messages types in Automations and Macros (#11741)
- OG Image in Chatwoot Help Center (#11826)
- Ability to mention team in private message (#11758)
- User attribution to Linear integration with actor authorization (#11774)
- Open conversation option (#11828)
- Notion OAuth setup (#11765)
- Support for image files in Captain (#11730)
- Voice channel creation flow (#11775)
- Captain access to private notes (#11768)
- Sync Popular Articles locale with widget locale (#11754)
- Expose custom attributes in conversation to Captain (#11769)

### Changed

- Make `captain_integration_v2` an internal feature (#11953)
- Add submenu for super admin settings (#11860)
- Move UpdateMessageStatus to deferred queue (#11943)
- Alphabetically sort inbox list on settings page (#11921)
- Auto assign PR to author when PR opened (#11890)
- Remove `defer` attribute from widget-loader script (#11887)
- Cancel redundant CI runs on consecutive pushes on the same PR (#11851)
- Disable drag on macro item when preview is open (#11847)
- Replace `content` with `outgoing_content` in webhook data (#11829)
- Remove older UI (#11720)
- Disable copilot usage after the response count is over (#11845)
- Add "Coming Soon" overlay to voice channel selector (#11835)
- Update Captain FAQ bulk action UI (#11780)
- Refactor account deletion email (#11772)
- Use state-based authentication (#11690)

### Fixed

- Fast scrolling in canned responses list on mouse hover (#11933)
- Contact name editing did not allow spaces (#11931)
- Approved FAQ not disappearing from pending list after filtering (#11909)
- Widget message input resize issue (#11896)
- Show billing upgrade page if there is a mismatch in the user count (#11886)
- Escape closing bracket in mention regex (#11877)
- Variable search item not showing after braces/commas (#11864)
- Incorrect account ID in conversation header back button URL (#11866)
- Handle emoji and special characters in mention notifications (#11857)
- `input_select` styles in Line channel (#11805)
- Do not enforce max_limits if inbox_auto_assignment is disabled (#11849)
- Revoke Linear OAuth token when integration is deleted (#11838)
- Unread badge style issue (#11846)
- CSAT table header and date range translation issue on reload (#11836)
- Support location messages in Twilio WhatsApp integration (#11830)
- disable_ddl_transaction! on add_index action (#11833)
- Add composite index on messages for csat_metrics API performance (#11831)
- Reply time calculation for re-opened conversations (#11787)
- Check if there are any subscriptions before we create a default subscription (#11813)
- Add missing CSAT URL in email reply templates (#11808)
- Upgrade letter_opener to fix `cannot load such file -- kconv error` (#11809)
- Disable push notifications (#11786)
- Translation issue in reports table headers on reload (#11793)
- Update ActiveStorage::FileNotFoundError error and fix captain condition in audio transcription (#11779)
- Handle Instagram user consent error for first-time message recipients (#11773)
- Respect messaging window constraints for auto-resolve messages (#11757)
- Resolve styling issues in multiselect (#11728)
- Incorrect conversation count shown for filters/folders after idle period (#11770)
- Disable custom context menu on img tags (#11762)

### Reverted

- Captain image support feature (#11841)

## [4.3.0] - 2025-06-17

### Added

- Audio transcriptions for self-hosted instances (#11755)
- Hide installation identifier (#11722)
- Super admin deletion of agent bots (#11748)
- Support for Telegram Business bots (#11663)
- Activity messages for Linear actions (#11654)
- i18n on WhatsApp list button (#10852)
- Hide CSAT survey URLs from agents in dashboard (#11622)
- Liquid processing for SMS campaigns (#10981)
- Label reports overview (#11194)
- Support for Telegram circular video messages (#11504)
- Enhance Linear integration UX with multi-issue support and improved placement (#11668)
- Development variant toggle rake task (#11696)
- Message support for `input_select` type in Facebook (#11627)
- Message support for `input_select` type in LINE (#11628)
- RTL support in public help center (#11692)
- Sanitize inbox name (#11597)
- Transcription support for audio messages (Enterprise) (#11670)
- Conversation delete feature (#11677)
- Rich text support for widget welcome tagline (#11666)
- Show active Contacts (#8243)
- Auto resolve label option and fixes (#11541)
- Improve article search ranking (#11640)
- Update UI for Copilot (#11561)
- Move embedding config to a yaml file (#11611)
- Enforce role permissions on filtered page (#11638)
- Custom roles seeding to account seeder (#11623)
- Tracking pixel for article view count (#11559)
- Ability to reset api_access_token (#11565)
- Show articles in the list only if feature is enabled (#11607)
- Update the UI to support change for Copilot as universal copilot (#11618)
- Allow searching articles in omnisearch (#11558)
- Support for Bunny CDN videos (#11601)
- Save timezone from LeadSquared API (#11583)
- Stores for copilotMessages and copilotThreads (#11603)
- Scroll lock on message context menu (#11454)
- Move Slack config to installation settings (#11548)
- Support for more tools, standardize copilot chat service (#11560)
- Automate account deletion (#11406)
- Support for the temperature field (#11554)
- Support for realtime-events in copilot-threads and copilot-messages (#11557)
- Embed for Wistia (#11547)
- Update Swagger to OpenAPI 3.0.4 with request payloads and examples (#11533, #11374)
- Ability to access user tokens via Platform API (#11537)
- Allow CORS API access (#11546)
- Support for additional tools in Copilot (#11531)
- Components to show steps in the copilot thinking process (#11530)
- Delete a contact from the contacts page (#11529)
- Support for search_conversations in copilot (#11520)
- Prevent saving preferences and status when impersonating (#11164)

### Changed

- Prevent count flicker on loading more conversations (#11726, #11706)
- Display divider only when multiple portals are available (#11709)
- Add region option to Dialogflow integration (#11510)
- Improvements for codespace (#11667, #11635, #11621)
- Mintlify docs migrate (#11641)
- Update design to fix the crowded header (#11633)
- Move URL comparison logic to utils (#11617)
- Add short_description translations for integration apps (#11562)
- Run RuboCop with auto fix (#11563)
- Upgrade Ruby version to 3.4.4 (#11524)
- Update Copilot UI in favor of the new design (#11544)
- Display Agent Bot token after creation (#11488)

### Fixed

- Hide Copilot launcher on inbox view message screen (#11723)
- Display "To" in email meta header on outgoing messages (#11717)
- Missing metrics and labels from label summary (#11718)
- Prevent display_name reset when updating password (#10374)
- Broken header in public Help Center portal (#11704)
- Prevent duplicate API calls for contact details when switching conversations (#9268)
- Send CSAT survey only when agent can reply in conversation (#11637, #11584)
- Avoid throwing 406 for non-json requests (#11701)
- Retry job if file not found (#11683)
- Incorrect date parsing in `matchesFilter` (#11679)
- Broken link in admin account user list (#11661)
- Show default dashboard prompt for contact and articles (#11675)
- Reset conversation sidebar when copilot is open (#11657)
- Style issue with conversation header (#11655)
- Style issue with CSAT reports table (#11653)
- Route params not reacting to changes (#11651)
- Force re-render the CSAT component when data changes (#11643)
- Allow users with report_manage permission to access CSAT reports (#11625)
- Design issues with profile settings style (#11630)
- Snackbar notifications hidden behind modal dialogs (#11616)
- Handle empty customDomain when checking for `isInternalLink` (#11609)
- External links in widget not opening in new tab (#11608)
- Use supported access method for schema_format in Rails 7 (#11576)
- Truncate name in attachment bubble (#11540)
- Update specs, add background response job implementation for copilot threads (#11600)
- Ignore private notes from the last 5 min when determining if an out of office message should be sent (#11552)
- Phone number handling in LeadSquared (#11527)
- Prevent creating duplicate messages via Instagram echo events (#11535)
- Rack-attack disable double Redis pooling (#11545)
- Twilio authentication handling for WhatsApp attachments (#11536)
- Account email validation during signup (#11307)
- Display message content for CSAT messages in non-widget inboxes (#11528)
- Status not updating when creating a Linear issue (#11523)

## [4.2.0] - 2025-05-20

### Added

- Tool to search Linear Issues in copilot (#11518)
- Concept of tool registry within Captain (#11516)
- Improve Captain interactions, activity messages (#11493)
- Development guidelines documentation for AI Agents (#11243)
- Activity message for conversation resolutions by Captain (#11492)
- Improve CSAT responses (#11485)
- Support for persistent copilot threads and messages (#11489)
- Teleport component to fix RTL/LTR utility classes (#11455)
- Scroll lock on chat list context menu (#11467)
- Allow agent bots to update custom attributes in accessible conversations (#11447)
- Support for typing events in webhooks (#11423)
- Support for trusted IPs to disable throttling (#11226)
- Allow auto resolve waiting option (#11436)
- Support for minutes in auto resolve feature (#11269)
- Handle Rails Turbo morphing (#11422)
- Update conversation basic filter (#11415)
- Generate test data for bulk insertion (#11229)
- Allow customizing the responses, flows in Captain (#11385)
- API Endpoints to update message status (#11387)
- Use numbers when fetching from the API (#11391)
- UI for contact notes (#11358)
- Integrate LeadSquared CRM (#11284)
- Widget opened and closed events (#11240)
- Custom domain to article URL if custom domain exists for the portal (#11349)

### Changed

- LLM formatter classes to include additional details (#11491)
- Make the table of contents in help center sticky (#11448)
- Update the copy for excluding the unattended conversations (#11450)
- Throttle staleContacts job (#11430)
- Use housekeeping queue for remove_stale_contacts job (#11435)
- Move staleContacts job to different Sidekiq queue (#11427)
- Update message bubble orientation (#11348)
- Enable stale contact removal job on Chatwoot Cloud (#11390)
- Improve plan-based feature handling with plan hierarchy (#11335)
- Upgrade utils to 0.0.43 (#11311)
- Update EE LICENSE year (#11344)
- Audit message characters across all channels (#11343)
- Migrated Instagram inbox warning style issues (#11332)
- Disable warnings old Instagram inbox for messenger conversations (#11329)
- Add the support for XML file in attachment (#11328)

### Fixed

- Fix the translation issue on conversation filter reload (#11513)
- Add available_name as method in captain_assistant (#11502)
- Move the check for CaptainAssistant to enterprise (#11500)
- CSAT select label dropdown overflow issue (#11499)
- Change button type for category icon in edit modal to prevent automatic form submission (#11498)
- Accidental contact creation on country dropdown toggle (#11494)
- Issues with custom attributes in conversation sidebar (#11476)
- Twilio multiple attachment fix (#11452)
- Manage Twilio SMS channel via inbox API (#11457)
- Handle Instagram user consent error for first-time message recipients (#11484)
- Duplicate attachments when navigating back to a conversation (#11472)
- Add named volumes for storage, postgres, and redis (#11465)
- Allow resource access without filter type in custom_filters API (#11445)
- Stale contacts job queue (#11434)
- Don't disable input for auto resolve (#11428)
- Undefined local variable or method `error` for an instance of Instagram MessageText (#11421)
- Update the character count for instructions (#11419)
- Show campaigns only if the feature is enabled (#11420)
- Show agent bot name and avatar correctly in messages (#11394)
- Fix missing translations in copilot (#11411)
- Update flag from countries.js (#11401)
- Hover issue with Linear issue popup (#11376)
- Alignment issue with logo in standard type bubble (#11364)
- Handle slug validation errors in Help Center (#11368)
- Update pre-commit hook to handle staged deleted files (#11357)
- Add missing 'hc' path segment after custom domain in article URLs (#11353)
- Inconsistent widget bubble focus outline shape (#11345)
- Prevent CC/BCC field reset on chat activity actions (#11342)
- Correct typo in CampaignConversationBuilder (#11336)

## [4.1.0] - 2025-04-16

### Added

- Implement UI for Agent Bots in settings and remove CSML support (#11276)
- Improve translation service with HTML and plain text support (#11305)
- Warnings for existing Instagram Messenger channels (#11303)
- Move email attachments from links to file attachments (#11304)
- Use portal logo as favicon in Help Center pages (#11289)
- Handle Instagram test service (#11244)
- Allow role based filtering on the frontend (#11246)
- Instagram Inbox using Instagram Business Login (#11054)
- Instagram reauthorization (#11221)
- Ability to create Instagram channel (#11182)
- Ability to delete account for administrators (#1874)
- Webhook event support for macros (#11235)
- Upgrade page instead of banner (#11202)
- Job to remove stale contacts and contact_inboxes (#11186)
- Long debounce for larger accounts (#11200)
- Debounce for meta query (#11195)
- Instagram channel migration (#11181)
- Support for frontend filtering of conversations (#11111)
- Cache to improve widget performance (#11163)

### Changed

- Move Instagram channel feature to GA (#11323)
- Enable chatwoot_v4 feature flag by default for accounts (#11321)
- Deprecate report_v4 feature flag and remove gating logic (#11320)
- Update PDF file text color from ruby to slate (#11313)
- Increase the timeout to support slow SMTP servers (#10318)
- Centralize outgoing message reply restrictions for all the channels (#11279)
- Remove sorting by `phone_number` from contact list (#11271)
- Update date range picker with new theme colors (#11267)
- Reply window fixes (#11242)
- Clean up report and knowledge base policies (#11234)
- Fix Facebook inbox create button (#11237)
- Improvements in automation and macros (#11231)
- Improve conversation permission filtering (#11166)
- Remove old buttons from Vue2 design (#11159)
- Update buttons in dashboard (#11145)
- Remove delete Instagram story implementation (#11097)

### Fixed

- Handle Instagram text and attachments as separate messages (#11315)
- Old Instagram inbox warnings (#11318)
- Email expand color (#11314)
- Emoji rendering issue with `<textarea/>` in Chrome (#11312)
- Stale report value shown if summary fetch breaks (#11270)
- Display error message on empty response from Captain (#11302)
- Hide message status for failed and deleted messages (#11294)
- Use stricter validation to restrict Gmail signups (#11285)
- Return new Array instead of frozen object (#11283)
- Handle Instagram echo events (#11275)
- Prevent mentions menu from triggering on reply mode change (#11264)
- Removing repetitive name parameter in AgentsController (#11259)
- Styles in ProseMirror URL prompt modal (#11256)
- Rendering issue with Pre-chat message (#11255)
- Support for named parameter templates in WhatsApp (#11198)
- Reset recorder and attachments when switching chats (#11174)
- Fix typo in conversationStats/get (#11201)
- Apply filter for inbox when the user is an admin (#11197)
- Update throttle for /meta endpoints (#11190)
- Remove where query if admin (#11183)
- Correct settings name translation in pt-BR (#11172)
- Support Business hours when downloading the agent reports

## [4.0.4] - 2025-03-21

### Added

- RTL Support to Widget (#11022)
- Support card message postback event as widget event (#11133)
- Support for multi-language support for Captain (#11068)
- Shopify Integration (#11101)
- Per-page support for agent and team overview report pagination (#11110)
- Update auth screens (#11108)
- Use GIN index for message search (#11107)
- Support for feature spotlight components (#11012)
- Use new compose conversation in conversation sidebar (#11085)
- Improvements in image attachment viewer (#11040)
- Live report for teams (#10849)
- Ignore out of sync messages (#11058)
- Use nocookie version of YouTube and Vimeo for help center embeds (#11061)
- Handle channel errors (#11015)
- Ability to filter items in Super Admin panel (#11020)
- UI element for secrets in superadmin (#11000)
- Ability to filter conversations with priority (#10967)
- June events for Linear integration (#11007)
- Support for account abuse detection (#11001)
- Allow copilot use without connecting an inbox (#10992)
- Move Linear config to installation_config (#10999)

### Changed

- Update buttons in conversation screens (#11134, #11132)
- Reduce meta conversation API calls (#11116)
- Update buttons across multiple pages (inbox, teams, agents, labels, custom attributes, automation, bots, macros, integrations, canned response, SLA, custom role) (#11127, #11128, #11129, #11126, #11125, #11124, #11123, #11122, #11121, #11120, #11118, #11119)
- Remove logging from search service (#11112)
- Update audio player input styles (#11106)
- Ignore notification when assignee is nil (#11105)
- Update styles in settings pages (#11070)
- Limit the number of articles retrieved by widget (#11095)
- Move Twilio event processing to background job (#11094)
- Update settings to match the new design (#11084)
- Update settings page to match the new design colors (#11072)
- Logger for non-existent WhatsApp channels (#11064)
- Add warning logs when Chatwoot receives events for inactive channels (#11066)
- Dynamically load OldSidebar if needed (#11038)
- Rescue Slack link unfurling errors (#11033)

### Fixed

- Do not allow sending messages if merged contact has a duplicate session (#11152)
- Theme inconsistency between portal page and widget (#11140)
- Fix duplicate contact inbox race condition (#11139)
- Duplicate action being sent when we click on save contact (#11138)
- Fix the issue with context menu for right click on images and videos (#11114)
- Dropdown for custom attributes in conversation sidebar hides under the list (#11099)
- Improve performance of most hit APIs in widget (#11089)
- Move contact events to account stream rather than individual user stream (#11082)
- Translate "None" option in automation select (#11076)
- Wrong copy with teams multi-select dropdown (#11075)
- Update translated content inline (#11074)
- Disable sending outgoing messages if the conversation is active (#11073)
- Email rendering issue with Google Drive link (#11069)
- Force re-render route i18n string (#11063)
- Translate "None" option in agent assignment dropdown (#11060)
- Add inbound_emails feature to the list of enabled features in paid account (#11055)
- Hide Configuration page for Microsoft and Gmail channels (#11045)
- Paginate attachments API (#11044)
- Extend the locale without variant check for article locales as well (#11021)
- Issue when saving hotkeys (#11026)
- Disable syncing IMAP if the account is suspended (#11031)
- Not using saved `order_by` when fetching conversation list (#11008)
- Process non-image inline attachments as regular attachments (#10998)
- Enable active record connection pool reaper (#10866)

## [4.0.3] - 2025-02-27

### Added

- Support for bulk action for Captain FAQs (#10905)
- Swagger endpoint for updating custom attributes (#10995)
- New APIs for live reports with team filter (#10994)
- Linear OAuth 2.0 (#10851)
- Setup ESLint for vue-i18n (#10889)
- Support bigger font size in dashboard (#10974)
- Support for citations in captain responses (#10958)
- Ability to delete platform app from super admin (#10966)

### Changed

- Improvement in keyboard shortcuts (#10925)
- Disable email notifications for unconfirmed users (#10964)

### Fixed

- Show "not-allowed" cursor for disabled buttons (#10986)
- Issue with compose conversation form (#10991)
- Issue with new conversation editor (#10985)
- `ComboBox` filtering delay in contact merge search (#10968)
- Usability issues in conversation card context menu (#10971)
- Update rendering logic for the "Read Documentation" link (#10965)
- Transcription email locales for pt_BR (#10952)
- Accented characters issue with variables in canned response (#10947)

## [4.0.2] - 2025-02-21

### Added

- Visibility checks for installation types (#10773)
- Don't hide thumbnail on hover (#10935)
- Invalidate cache after inbox members or team members update (#10869)
- Hide tokens and password on contact inbox payloads (#10888)
- Validate sender before creating campaign (#10934)
- Allow users to see heatmap for last 30 days (#10848)
- Upgrade Dyte APIs to v2 (#10706)
- Update vue-letter and allow transform CSS (#10865)
- Add the ability to block/unblock contact via contact details page (#10899)
- Ability to rearrange macros in sidebar (#10879)
- Docker ARM64 builds for EE edition (#10891)
- Multiple attachment support for Telegram channel (#10883)
- Use feature flags across the routes (#10797)
- Show shared contact's name in Telegram channel (#10856)
- Reload conversation data in ActionCableBroadcastJob before sending (#10876)
- Support for Telegram contact sharing (#10841)
- Show email subject in conversation search results (#10843)
- Order previous conversations by last activity (#10825)
- Unread badge to sidebar for inbox view (#10803)
- Hide empty folders from sidebar (#10786)
- Switch to native ARM64 runners for Docker CE images (#10789)
- Add OOMPolicy for Sidekiq systemd service (#10772)
- Update the report pages to show aggregate values (#10766)
- Frontend changes for Captain limits (#10749)
- Setup Captain limits (#10713)
- Prompt suggestions and June events (#10726)
- Add CSAT and Form bubble (#10711)

### Changed

- Clean up the feature presentation in super admin (#10949)
- Slack file upload changes (#10903)
- Switch html2text back to rubygems (#10911)
- Add internal feature flags for Chatwoot Cloud (#10902)
- Sync translations, add pnpm sync:i18n command (#10893)
- Add GitHub action to test Docker builds against PRs (#10892)
- Show deprecation warnings in dev only (#10868)
- Remove the background SVG from the help center (#10857)
- Update the precision of the updated_at timestamp in conversation model (#10875)
- Add updated_at attribute to the conversation event (#10873)
- Bump up cwctl version to 3.2.0 (#10850)
- Search improvements (#10801)
- Resolve flaky spec for Contact country sorting (#10810)
- Update the behavior of Captain resolutions (#10794)
- Use `getFileInfo` helper from utils (#10819)
- Update copyright year to 2025 (#10817)
- Always display the extension of an attached file (#10806)
- Next bubble improvements (#10759)
- Disable audio alert for `pending` status conversation (#10777)
- Disable account switcher for single-account users (#10768)
- Design improvements (#10732)
- Help center improvements (#10712)
- Auto-fetch previous page on last item deletion (#10714)

### Fixed

- Reports chart by removing y-axis numeric labels (#10941)
- Incorrect translation in contact merge modal and resolve z-index issue (#10943)
- Issues with leave room button (#10942)
- Issues in bubble design (#10940)
- Convert seconds based metric tooltips to readable format (#10938)
- Handle empty FIRECRAWL_KEY in captain crawl job (#10936)
- Logo and custom branding (#10930)
- Join Dyte meeting URL in dashboard (#10932)
- Wrong toast message on creation of a Live Chat campaign (#10919)
- Disable branding on help center if the feature is turned on (#10916)
- Handle JSON requests in DashboardController (#10910)
- Use textContent as fallback for htmlContent instead of content.value (#10901)
- UI issue with `pt-Br` locale (#10897)
- Initialize SDK along with emitter registration (#10896)
- Move auto resolution message text content to i18n file (#10881)
- TypeError - Cannot read properties of null (reading 'name') (#10887)
- Inconsistent reply box cc update (#10799)
- Handle mine event for incoming messages (#10867)
- Message signature is not appending (#10855)
- Re-rendering of components when shifting from the unread list to the read list (#10835)
- onboarding/index.html.erb unclosed HTML tags (#10838)
- Incorrect sender name on email meta (#10837)
- Corepack pnpm issue (#10840)
- Update the photo/video caption when an update event is received (#10804)
- Prevent compose modal from closing when creating a link (#10809)
- Update min-length validation for the contact to support names with single characters (#10813)
- Docker GitHub action for CE images (#10800)
- Download file CORS issue (#10787, #10755)
- Update Captain billing colors (#10782)
- Use `current_available` instead `available` to compute the document limit (#10776)
- Prevent template variables from becoming links (#10725)
- Prevent duplicate chat creation in the web widget during latency (#10745)
- Added authentication to FireCrawl API, remove unused RobinAI references (#10737)
- Country selection (#10670)
- Context menu and its submenu boundary overflow (#10729)
- Use documentable instead of document (#10743)
- Check the edition before running the data migration (#10728)
- Vite dev build fails due to sass (#10716)
- Check if item is present (#10715)
- Download button opens URL instead of downloading (#10710)

### Reverted

- Next bubble improvements (#10795)

## [4.0.1] - 2025-01-17

### Fixed

- Bubble colors for email and text (#10701)
- Remove backdrop-blur from Modal (#10709)
- Re-enable scheduled jobs (#10708)
- Rendering for woot modal (#10707)

### Changed

- Update SECURITY.md (#10705)

## [4.0.0] - 2025-01-16

Initial v4 release with major UI redesign and new features.

[v4.9.1]: https://github.com/chatwoot-br/chatwoot/compare/v4.9.0...v4.9.1
[4.9.0]: https://github.com/chatwoot/chatwoot/compare/v4.8.0...v4.9.0
[4.8.0]: https://github.com/chatwoot/chatwoot/compare/v4.7.0...v4.8.0
[4.7.0]: https://github.com/chatwoot/chatwoot/compare/v4.6.0...v4.7.0
[4.6.0]: https://github.com/chatwoot/chatwoot/compare/v4.5.2...v4.6.0
[4.5.2]: https://github.com/chatwoot/chatwoot/compare/v4.5.1...v4.5.2
[4.5.1]: https://github.com/chatwoot/chatwoot/compare/v4.5.0...v4.5.1
[4.5.0]: https://github.com/chatwoot/chatwoot/compare/v4.4.0...v4.5.0
[4.4.0]: https://github.com/chatwoot/chatwoot/compare/v4.3.0...v4.4.0
[4.3.0]: https://github.com/chatwoot/chatwoot/compare/v4.2.0...v4.3.0
[4.2.0]: https://github.com/chatwoot/chatwoot/compare/v4.1.0...v4.2.0
[4.1.0]: https://github.com/chatwoot/chatwoot/compare/v4.0.4...v4.1.0
[4.0.4]: https://github.com/chatwoot/chatwoot/compare/v4.0.3...v4.0.4
[4.0.3]: https://github.com/chatwoot/chatwoot/compare/v4.0.2...v4.0.3
[4.0.2]: https://github.com/chatwoot/chatwoot/compare/v4.0.1...v4.0.2
[4.0.1]: https://github.com/chatwoot/chatwoot/compare/v4.0.0...v4.0.1
[4.0.0]: https://github.com/chatwoot/chatwoot/releases/tag/v4.0.0
