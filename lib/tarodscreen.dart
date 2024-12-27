import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rive/rive.dart' hide Image;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'main.dart';
import 'VideoPreloadManager.dart';

class GlobalTarodVideoState {
  static bool hasPlayedOpenAnimation = false;
}

class TarodScreen extends StatefulWidget {
  final VideoPlayerController? transitionController;

  const TarodScreen({
    Key? key,
    this.transitionController,
  }) : super(key: key);

  @override
  _TarodScreenState createState() => _TarodScreenState();
}

class _TarodScreenState extends State<TarodScreen> with WidgetsBindingObserver, TickerProviderStateMixin, RouteAware {
  VideoPlayerController? _videoController; // Dreamidle.mp4
  VideoPlayerController? _dreamTarodController; // Dreamtarod.mp4
  VideoPlayerController? _dreamCardController; // Dreamcard.mp4
  late VideoPreloadManager _preloadManager;
  bool _canRenderContent = false;

  bool _isLoading = false;

  bool _isAnalyzingAnimation = false; // 控制卡牌縮小 & loading

  // 狀態控制
  int _currentPage = 1;

  final List<String> firstRoundOptions = ['愛情', '事業', '人際', '家庭', '錢財'];
  List<String> secondRoundOptions = [];

  final Map<String, Color> _cardColorMap = {
    '愛情': Colors.pink.shade300,
    '事業': Colors.lightBlue.shade300,
    '人際': Colors.lightGreen.shade300,
    '家庭': Colors.orange.shade300,
    '錢財': Colors.purple.shade300,

    '單身': Colors.pink.shade200,
    '有穩定的伴侶': Colors.pink.shade200,
    '處於曖昧中': Colors.pink.shade200,
    '感情遇到困難': Colors.pink.shade200,

    '穩定就業': Colors.lightBlue.shade200,
    '正在尋找新工作': Colors.lightBlue.shade200,
    '希望事業有突破': Colors.lightBlue.shade200,
    '考慮轉職或創業': Colors.lightBlue.shade200,

    '有密友並常常交流': Colors.lightGreen.shade200,
    '人際關係還可以，但希望拓展': Colors.lightGreen.shade200,
    '感到孤獨，缺乏交流': Colors.lightGreen.shade200,
    '與某人關係緊張，需要修復': Colors.lightGreen.shade200,

    '家庭穩定，感覺溫馨': Colors.orange.shade200,
    '正在面臨家庭的變動或挑戰': Colors.orange.shade200,
    '與家人相處和諧但有些小問題': Colors.orange.shade200,
    '與某位家庭成員存在摩擦': Colors.orange.shade200,

    '穩定，無需擔憂': Colors.purple.shade200,
    '正在存錢，努力達成目標': Colors.purple.shade200,
    '有些經濟壓力，但可控': Colors.purple.shade200,
    '遇到財務困難，需要解決': Colors.purple.shade200,
  };


  String? _firstSelection;
  String? _secondSelection;
  List<Uint8List> _generatedImages = [];
  String serverUrl = 'https://8f8d-140-124-28-150.ngrok-free.app';

  bool _isCardBookOpened = false;

  bool _isAnalyzing = false;
  bool _showSlideUpHint = false;
  bool _imageFullyVisible = false;
  bool _isFlipped = false;
  bool _showCollectHint = false;

  bool _isCardMoving = false;
  bool _isDreamTarodPlaying = false;

  late AnimationController _firstCardController;
  late Animation<Offset> _firstCardAnimation;

  late AnimationController _secondCardController;
  late Animation<Offset> _secondCardAnimation;

  final Alignment _firstTargetAlignment = Alignment.bottomLeft;
  final Alignment _secondTargetAlignment = Alignment.bottomRight;

  final Alignment _initialCardAlignment = Alignment.topCenter;

  bool _isMoving = false;
  String? _movingCardText;
  Alignment _cardAlignment = Alignment.topCenter;

  final GlobalKey _firstTargetKey = GlobalKey();
  final GlobalKey _secondTargetKey = GlobalKey();

  final Map<String, GlobalKey> _cardKeys = {};

  String _currentExplanation = '';
  OverlayEntry? _explanationOverlay;
  GlobalKey<FlipCardState> _flipCardKey = GlobalKey<FlipCardState>();

  late AnimationController _moveShrinkController;
  late Animation<Offset> _moveAnimation;
  late Animation<double> _shrinkAnimation;

  bool _showClickToFlipHint = false;
  bool _showLongPressHint = false;

  // 問題選項映射
  Map<String, List<String>> promptMapping = {
  // 愛情 - 單身
  '愛情 - 單身': [
  // Prompts 1-4
  "A person standing in a moonlit field, gazing at the stars, surrounded by glowing mystical creatures and soft light. The scene is rendered in a dream-like, whimsical illustration style, with fantastical creatures blending harmoniously with the night’s ethereal glow.illustration",
  "A person walking through a forest path, with a glowing figure appearing ahead, ethereal and inviting. The scene is depicted in a dreamy, fantasy illustration style, with soft beams of light and mythical creatures surrounding the path.illustration",
  "A person sitting on a cliff at sunset, looking out into the horizon, surrounded by mysterious creatures in the distance. The illustration is dreamlike, with the sky painted in soft hues and ethereal creatures adding a touch of magic to the scene.illustration",
  "A person standing on a bridge over a misty river, a distant figure waiting on the other side, softly glowing. The illustration captures a dreamlike essence with swirling mist and fantasy elements, bringing a sense of anticipation and possibility.illustration",
  ],
  // 愛情 - 有穩定的伴侶
  '愛情 - 有穩定的伴侶': [
  // Prompts 5-8
  "A couple sitting side by side on a cliff overlooking a serene valley, with gentle light illuminating their figures. The scene is depicted in a dreamlike, whimsical illustration style, where mystical creatures hover around them, symbolizing harmony and connection.illustration",
  "A couple standing together in a forest, hand in hand, facing a distant mountain, the path ahead illuminated by soft moonlight. The illustration captures a mystical, dream-like atmosphere with ethereal creatures that guide their way forward.illustration",
  "A couple sitting together by a lake, facing each other, their hands gently touching as glowing fireflies dance around them. The scene is rendered in a dreamy, fantastical illustration style, with mystical elements in the environment symbolizing growth and understanding.illustration",
  "A couple standing at the edge of a tranquil meadow, gazing at the sunrise in the distance. The illustration, in a dreamy and mystical style, features glowing creatures that symbolize new beginnings and shared hopes for the future.illustration",
  ],
  // 愛情 - 處於曖昧中
  '愛情 - 處於曖昧中': [
  // Prompts 9-12
  "Two figures standing on a misty bridge, exchanging a glance, surrounded by glowing ethereal creatures and soft light that hints at the beginning of something special.illustration",
  "A couple walking together on a woodland path, holding lanterns that cast a soft glow. The scene is filled with gentle mythical creatures and soft light, representing the growing clarity in their connection.illustration",
  "Two figures walking side by side in a magical forest, their steps soft and careful, with ethereal creatures in the background guiding their path. The scene feels thoughtful, reflecting the cautious but growing connection between them.illustration",
  "A person standing at the edge of a tranquil lake, gazing at a distant, glowing figure. The image is surrounded by soft mist and glowing creatures, symbolizing hope amidst uncertainty.illustration",
  ],
  // 愛情 - 感情遇到困難
  '愛情 - 感情遇到困難': [
  // Prompts 13-16
  "A couple standing together under a stormy sky, their hands clasped tightly, while glowing creatures surround them offering support.illustration",
  "A couple sitting across from each other at a table in a forest, gently talking as mythical creatures watch over them, their conversation illuminating the path ahead.illustration",
  "A couple standing on opposite ends of a small bridge, gazing at each other, with glowing creatures bridging the gap between them.illustration",
  "A couple walking together down a foggy path, with soft light shining from ahead, guiding them through the mist. Glowing creatures hover around, symbolizing guidance and hope.illustration",
  ],
  // 事業 - 穩定就業
  '事業 - 穩定就業': [
  // Prompts 1-4
  "A person standing at a crossroads in a lush forest, looking at a glowing path ahead, with mythical creatures guiding the way.illustration",
  "A person standing at the base of a large mountain, gazing at the summit, with ethereal creatures offering encouragement from above.illustration",
  "A person standing in a grand hall, holding a glowing orb, while mythical creatures hover around, signifying growth and responsibility.illustration",
  "A person standing before a glowing portal in a forest, with mystical creatures waiting to guide them through to a new realm of possibilities.illustration",
  ],
  // 事業 - 正在尋找新工作
  '事業 - 正在尋找新工作': [
  // Prompts 5-8
  "A person walking along a winding path in a mystical forest, with glowing creatures around, leading them toward an unknown but hopeful future.illustration",
  "A person standing at the edge of a glowing cliff, gazing out at a bright new horizon, with mythical creatures flying toward the future.illustration",
  "A person standing in a bustling marketplace, exchanging ideas with various figures and mythical creatures, surrounded by glowing lights symbolizing new connections.illustration",
  "A person standing before a glowing gate in a mystical forest, with creatures surrounding them, representing a moment of decision and new challenges ahead.illustration",
  ],
  // 事業 - 希望事業有突破
  '事業 - 希望事業有突破': [
  // Prompts 9-12
  "A person standing at the foot of a glowing mountain, gazing at the peak above, with mystical creatures guiding their way.illustration",
  "A person standing in a vast open field, watching a glowing portal appear, surrounded by ethereal creatures, symbolizing new opportunities.illustration",
  "A person holding a glowing orb in their hand, standing on a bridge in a mystical forest, with mythical creatures assisting them.illustration",
  "A person standing before a glowing door in a misty forest, with mythical creatures guiding them through the mist toward a new direction.illustration",
  ],
  // 事業 - 考慮轉職或創業
  '事業 - 考慮轉職或創業': [
  // Prompts 13-16
  "A person standing at the edge of a glowing forest, looking at a distant, open field full of light, with mystical creatures leading the way forward.illustration",
  "A person walking through a misty mountain pass, with glowing creatures guiding them toward the unknown.illustration",
  "A person standing in a vast, illuminated city with glowing bridges, looking toward a glowing door that opens to endless possibilities.illustration",
  "A person standing at the entrance of a glowing, magical workshop, surrounded by ethereal creatures and the hum of creation.illustration",
  ],
  // 人際關係領域的選項
  '人際 - 有密友並常常交流': [
  // Prompts 1-4
  "A group of people sitting around a glowing campfire in a mystical forest, smiling and talking, with glowing creatures surrounding them.illustration",
  "A person standing in a lush garden, greeting new figures and mythical creatures, while the sun sets behind them.illustration",
  "Two people sitting together under a large tree, having a deep conversation with glowing creatures hovering above, representing understanding and clarity.illustration",
  "A group of people standing together on a bridge, facing a distant glowing light, with mythical creatures offering support along the way.illustration",
  ],
  '人際 - 人際關係還可以，但希望拓展': [
  // Prompts 5-8
  "A person standing in a bustling, enchanted marketplace, meeting new figures and glowing creatures, with a soft light illuminating the new connections.illustration",
  "A person walking through a glowing forest path, surrounded by ethereal creatures, meeting new figures who symbolize deeper connections.illustration",
  "A person standing at the entrance of a glowing gate in a mystical world, looking into the horizon filled with potential and new friendships.illustration",
  "A person standing in a meadow, surrounded by new figures and glowing creatures, each offering a chance to form new connections.illustration",
  ],
  '人際 - 感到孤獨，缺乏交流': [
  // Prompts 9-12
  "A person standing alone in a misty forest, looking at a glowing light in the distance, symbolizing a path to new connections.illustration",
  "A person walking towards a glowing doorway surrounded by mystical creatures, representing the opportunity for new connections.illustration",
  "A person sitting by a peaceful lake, writing in a journal, with ethereal creatures around, representing the act of sharing thoughts and feelings.illustration",
  "A person standing on a bridge, looking at a distant glowing city, with mystical creatures guiding the way.illustration",
  ],
  '人際 - 與某人關係緊張，需要修復': [
  // Prompts 13-16
  "Two people standing on opposite sides of a glowing bridge, reaching out to each other as mystical creatures watch over them.illustration",
  "Two figures standing together in a glowing forest, working to repair a glowing path that had once been broken.illustration",
  "Two people sitting together under a glowing tree, exchanging stories while mythical creatures surround them, representing the building of trust.illustration",
  "Two figures standing in front of a glowing doorway, ready to step forward together, surrounded by ethereal creatures.illustration",
  ],
  // 家庭領域的選項
  '家庭 - 家庭穩定，感覺溫馨': [
  // Prompts 1-4
  "A family gathered around a glowing bonfire in a magical forest, laughing and enjoying each other's company, with mystical creatures nearby.illustration",
  "A family standing together on a bridge, holding hands and gazing at a distant glowing light, with ethereal creatures offering support along the way.illustration",
  "A family sitting together around a table, sharing a meal and celebrating, with glowing creatures in the background.illustration",
  "A family walking together through a glowing field, with glowing creatures leading the way, symbolizing a journey toward a bright future.illustration",
  ],
  '家庭 - 正在面臨家庭的變動或挑戰': [
  // Prompts 5-8
  "A family standing together in a storm, their hands clasped tightly as glowing creatures surround them, symbolizing strength and resilience.illustration",
  "A family standing in front of a glowing portal, stepping forward together with mythical creatures guiding the way.illustration",
  "A family gathered around a table, discussing plans while ethereal creatures appear in the background, symbolizing unity and progress.illustration",
  "A family walking together through a mystical forest, with glowing creatures guiding them toward a distant, glowing city symbolizing new opportunities.illustration",
  ],
  '家庭 - 與家人相處和諧但有些小問題': [
  // Prompts 9-12
  "A family standing in a sunlit clearing, exchanging smiles and laughter, while gentle, glowing creatures surround them, symbolizing support and understanding.illustration",
  "A family sitting together by a glowing tree, sharing their thoughts with each other, while ethereal creatures hover around, symbolizing the resolution of misunderstandings.illustration",
  "A family standing together at the base of a glowing mountain, holding hands as they look up at the peak, surrounded by soft light and mystical creatures.illustration",
  "A family walking together through a peaceful forest, with glowing creatures appearing along the path, symbolizing solutions and calmness.illustration",
  ],
  '家庭 - 與某位家庭成員存在摩擦': [
  // Prompts 13-16
  "Two figures standing at opposite ends of a glowing bridge, reaching toward each other, with mystical creatures offering light and guidance.illustration",
  "Two people sitting together beneath a glowing tree, sharing thoughts with ethereal creatures circling above, symbolizing understanding and reconciliation.illustration",
  "Two figures standing at the base of a glowing mountain, looking at the peak together, with glowing creatures guiding them through the mist.illustration",
  "A family standing in front of a glowing portal, with mystical creatures guiding them forward, symbolizing trust and renewed connection.illustration",
  ],
  // 金錢領域的選項
  '金錢 - 穩定，無需擔憂': [
  // Prompts 1-4
  "A person walking through a glowing forest path, with mystical creatures by their side, representing steady progress and the emergence of new financial opportunities.illustration",
  "A person standing at the edge of a misty cliff, gazing at a distant mountain with creatures flying above, symbolizing potential financial challenges ahead.illustration",
  "A person sitting at a desk surrounded by glowing books and financial charts, with ethereal creatures providing guidance and ideas for future financial growth.illustration",
  "A person standing before a glowing, closed door in a mystical landscape, with creatures surrounding them, symbolizing a need to reassess and replan their financial path.illustration",
  ],
  '金錢 - 正在存錢，努力達成目標': [
  // Prompts 5-8
  "A person standing by a glowing fountain, collecting golden coins in a jar, with mystical creatures floating around, symbolizing progress and accumulation.illustration",
  "A person sitting at a desk, surrounded by glowing financial charts and symbols, while ethereal creatures guide them towards their goa.illustration",
  "A person standing in a misty field, holding a jar of coins, while glowing creatures hover overhead, symbolizing the need for patience and persistence.illustration",
  "A person looking at a map, surrounded by glowing creatures, representing the search for better strategies and more efficient ways to reach their financial goals.illustration",
  ],
  '金錢 - 有些經濟壓力，但可控': [
  // Prompts 9-12
  "A person standing under a glowing tree in a peaceful forest, holding a glowing orb symbolizing balance and control over their financial situation.illustration",
  "A person standing on a glowing bridge, with ethereal creatures watching over them, symbolizing careful financial planning and caution.illustration",
  "A person holding a glowing lantern, walking down a misty path surrounded by glowing creatures, symbolizing the search for solutions and external support.illustration",
  "A person standing in front of a glowing door, looking toward a distant mountain, with mythical creatures guiding the way, symbolizing upcoming challenges.illustration",
  ],
  '金錢 - 遇到財務困難，需要解決': [
  // Prompts 13-16
  "A person standing at a glowing crossroads, holding a map, with ethereal creatures pointing in different directions, symbolizing the search for a solution.illustration",
  "A person walking through a misty forest, holding a glowing lantern, with mystical creatures by their side, symbolizing the search for guidance and support.illustration",
  "A person standing at the edge of a glowing cliff, gazing at a distant mountain, with ethereal creatures encouraging them to keep going despite the challenges.illustration",
  "A person walking slowly through a foggy landscape, with glowing creatures lighting the way, representing slow but steady progress toward financial recovery.illustration",
  ],
};

  // 在狀態類中定義說明文字列表
  Map<String, Map<String, String>> explanationMapping = {
    '愛情 - 單身': {
        '滿意並感到幸福': '你目前單身並感到滿足，這是一段重要的自我探索與成長期。未來幾個月，可能會遇到與你契合的人，這段邂逅將帶來新的快樂。',
        '希望能更加了解對方': '雖然你目前單身，但內心渴望遇到一個可以深入了解的人。未來幾個月，可能會有機會遇見新的人，這將是開始新關係的好時機。',
        '感到不安或缺乏信任': '你對愛情有所期待，但同時也感到不安或擔心。未來的幾個月中，你可能會逐漸釋放過去的陰影，重新對愛情建立信任。',
        '需要更多的改變或努力': '你渴望愛情，但感覺需要在自我或生活中做出改變。未來幾個月，你可能會參與更多社交活動，幫助你打開心扉並找到愛情。',
      },
      '愛情 - 有穩定的伴侶': {
        '滿意並感到幸福': '你和伴侶的感情穩定且幸福，未來的幾個月中，你們可能共同迎來更多美好的時光，例如一起旅行或完成共同目標。',
        '希望能更加了解對方': '你希望和伴侶之間有更深入的了解，未來幾個月中，你們可能會經歷一些挑戰，這些挑戰將讓你們看到彼此更多的面向，從而加深理解。',
        '感到不安或缺乏信任': '你和伴侶之間可能存在一些信任上的問題，未來幾個月中，通過更多的坦誠交流和理解，你們可以逐漸重建這段感情的信任。',
        '需要更多的改變或努力': '你覺得目前的關係需要一些改變來變得更好，未來幾個月中，你們將面臨一些挑戰，這些改變將使你們的感情更加穩固。',
      },
      '愛情 - 處於曖昧中': {
        '滿意並感到幸福': '你正處於一段甜蜜的曖昧關係中，這段關係讓你充滿期待和幸福感。未來幾個月中，這段曖昧有可能演變成穩定的戀愛關係。',
        '希望能更加了解對方': '你希望能對方能更清楚地表達情感，未來幾個月中，你們將有更多交流機會，從而更深入地了解對方的想法。',
        '感到不安或缺乏信任': '你對這段曖昧關係感到不安，不確定對方的真實想法。未來的幾個月中，你們會有機會進行坦誠交流，以更加明確彼此的感受',
        '需要更多的改變或努力': '你希望這段曖昧關係能有所突破，但這需要雙方更多的努力和改變。未來的幾個月中，你可能會主動尋找機會，加深彼此的互動。',
      },
      '愛情 - 感情遇到困難': {
        '滿意並感到幸福': '儘管你和伴侶目前遇到一些困難，但你依然感到幸福，相信這些困難只是暫時的，你們的感情會因此而更加堅強。',
        '希望能更加了解對方': '你和伴侶目前的溝通可能有些障礙，但你願意花時間來更好地了解對方，未來的幾個月中，你們可能會有更多機會來增進彼此理解。',
        '感到不安或缺乏信任': '你和伴侶之間可能存在不信任的問題，未來幾個月中，你們將有機會通過努力來重建信任，並加深彼此的情感連結。',
        '需要更多的改變或努力': '你覺得這段感情目前需要更多的努力和改變來改善，未來幾個月中，你們將共同面對挑戰，努力讓這段感情變得更加穩定。',
      },
      '事業 - 穩定就業': {
        '壓力適中，可以應對': '你目前的工作穩定，壓力在可控範圍內。未來幾個月，你可能會參與一些新的專案，這將幫助你成長並獲得更多職業成就感。',
        '壓力很大，渴望改善': '你在穩定的工作中感受到較大的壓力，但未來幾個月你會找到一些有效的方法來減輕壓力，可能是改變工作流程或找到新的支持。',
        '工作有點枯燥，希望變化': '你目前對工作內容感到有些枯燥，渴望一些變化。未來幾個月，你將有機會接觸到新的職務或學習新技能，這將重新激發你的工作熱情。',
        '熱愛目前的工作內容': '你熱愛目前的工作，並對職業發展充滿熱情。未來的幾個月中，你可能會有機會承擔更多責任，這將進一步提升你的成就感。',
      },
      '事業 - 正在尋找新工作': {
        '壓力適中，可以應對': '你目前正在尋找新的工作機會，雖然過程中有一些壓力，但你保持積極的心態，相信自己能找到合適的機會。',
        '壓力很大，渴望改善': '找工作的壓力讓你感到焦慮，但未來幾個月你將通過提升技能和擴展人脈找到合適的機會，這將有助於緩解目前的壓力。',
        '工作有點枯燥，希望變化': '你對目前的工作感到枯燥無趣，因此正在尋找一個能帶來更多變化和挑戰的新機會。未來幾個月，你可能會發現適合你的工作，帶來新的挑戰。',
        '熱愛目前的工作內容': '你希望找到新的工作，但也想保留目前熱愛的工作內容。未來幾個月，你將有機會找到一個能融合你現有技能的新職位。',
      },
      '事業 - 希望事業有突破': {
        '壓力適中，可以應對': '你渴望在事業上有突破，並且準備好應對挑戰。未來幾個月中，你將參與一些新的專案，這些專案將幫助你進一步提升職業技能。',
        '壓力很大，渴望改善': '你目前在追求事業突破時感受到很大壓力，但未來你將找到更有效的方法來平衡工作與生活，並朝著事業目標前進。',
        '工作有點枯燥，希望變化': '你希望在工作中取得突破，並想改變目前枯燥的狀況。未來幾個月，你將有機會接觸到新的項目或部門，這將帶來更多挑戰和機會。',
        '熱愛目前的工作內容': '你熱愛目前的工作，同時也希望取得突破。未來幾個月，你將可能得到升職或參與一個大型的項目，這將進一步提升你的成就感。',
      },
      '事業 - 考慮轉職或創業': {
        '壓力適中，可以應對': '你目前在考慮轉職或創業，這是一個充滿挑戰但也充滿機會的時期。未來幾個月，你將對市場進行深入調查，並做好充足的準備。',
        '壓力很大，渴望改善': '你對轉職或創業充滿期待，但同時也感到很大的壓力。未來幾個月中，你可能會得到來自朋友或專家的建議，這將幫助你更有信心地做出決定。',
        '工作有點枯燥，希望變化': '你目前感到工作有些乏味，正在考慮轉職或創業，尋找更具挑戰性的新方向。未來幾個月，你將發現適合你的創業機會，帶來期待已久的變化。',
        '熱愛目前的工作內容': '你喜愛目前的工作內容，但同時也在考慮轉職或創業來追求更多的自由和成就感。未來幾個月，你將深入研究創業的可能性，找到讓你充滿激情的新方向。',
      },
      '人際 - 有密友並常常交流': {
        '有密友並常常交流，關係和睦且互相關心': '你擁有穩定的友情和和睦的家庭關係，未來幾個月，你會繼續與朋友和家人保持良好的交流，並共同度過許多美好的時光。',
        '有密友並常常交流，偶爾有矛盾，但無大礙': '你擁有良好的友誼和家庭，但偶爾會有些小摩擦。未來幾個月，你將學會更多地包容和理解，這將使你的人際關係更加和諧。',
        '有密友並常常交流，目前存在一些溝通障礙': '你在家庭中感到有些溝通上的障礙，但你的友誼穩定。未來的幾個月中，你將有機會通過家庭活動來增進理解，改善這些障礙。',
        '有密友並常常交流，正在努力修復關係': '你的友誼充實，但目前正努力修復與某位家人的關係。未來幾個月，通過更多的交流和理解，你將逐漸找到合適的方法來解開心結。',
      },
      '人際 - 人際關係還可以，但希望拓展': {
        '關係和睦且互相關心': '你在人際關係中感到滿意，但希望拓展更多的友情圈子，家庭關係則和睦。未來幾個月，你將參加一些社交活動，擴展你的人際網絡。',
        '偶爾有矛盾，但無大礙': '你希望擴展朋友圈，並且在家庭中偶爾有一些小矛盾。未來幾個月，你將通過更好的溝通來減少矛盾，同時也將找到新的社交圈。',
        '目前存在一些溝通障礙': '你感到在人際交往中需要拓展更多朋友，但家庭中有些溝通問題。未來幾個月中，你可能會找到改善家庭溝通的機會，同時擴大你的社交圈。',
        '正在努力修復關係': '你希望認識更多新朋友，同時正在努力修復與某位家人的關係。未來幾個月中，更多的交流將讓你在人際和家庭關係中都有所改善。',
      },
      '人際 - 感到孤獨，缺乏交流': {
        '關係和睦且互相關心': '你在友情中感到孤獨，但家庭中關係和睦。未來幾個月，你將有機會在家庭的支持下，參加更多的社交活動，認識新朋友。',
        '偶爾有矛盾，但無大礙': '你在人際中感到孤獨，家庭中則偶爾有些小矛盾。未來幾個月，你將通過改變自己的社交方式來改善孤獨感，同時增強家庭的和睦。',
        '目前存在一些溝通障礙': '你在人際和家庭中都有些溝通問題，感到孤獨。未來幾個月中，通過自我反省和更多嘗試，你將逐漸打開心扉，與家人和朋友建立更深的連結。',
        '正在努力修復關係': '你在人際關係中感到孤獨，但正積極努力修復與家人的關係。未來幾個月中，通過修復家庭中的關係，你將逐漸找到更多的支持和陪伴。',
      },
      '人際 - 與某人關係緊張，需要修復': {
        '關係和睦且互相關心': '你與某位朋友的關係有些緊張，但家庭中關係和睦。未來幾個月，你將有機會通過家庭的支持來修復這段友情。',
        '偶爾有矛盾，但無大礙': '你和某位朋友的關係緊張，家庭中偶爾也有些小矛盾。未來幾個月中，更多的坦誠交流將有助於解開彼此之間的心結。',
        '目前存在一些溝通障礙': '你在人際和家庭中都有些溝通上的困難。未來幾個月中，你需要更多地反省自己，並嘗試更有效的交流方法來改善這些關係。',
        '正在努力修復關係': '你與某位朋友的關係緊張，也正努力修復與家人的關係。未來幾個月中，通過更多的耐心和理解，你將找到改善這些關係的方法。',
      },
      '家庭 - 家庭穩定，感覺溫馨': {
        '感到滿足和安全': '你對家庭感到滿足且安全，這是你生活中最重要的支持來源。未來幾個月，你將享受更多家庭中的溫馨時光，這將進一步強化你對家庭的感覺。',
        '希望有更多時間陪伴家人': '雖然你的家庭狀況穩定且溫馨，但你希望有更多時間與家人相處。未來幾個月，你將找到一些機會抽出時間來與家人共度美好時光。',
        '感到責任壓力較大': '你在穩定的家庭中感受到一定的責任壓力。未來幾個月，你將學會更好地分擔家庭責任，這將使你感到更加輕鬆自在。',
        '希望家庭氛圍能更輕鬆': '雖然你的家庭關係穩定，但你希望家庭氛圍更加輕鬆。未來幾個月，你將通過一些小改變，例如家庭聚會或休閒活動，使家庭的氛圍變得更加愉悅。',
      },
      '家庭 - 正在面臨家庭的變動或挑戰': {
        '感到滿足和安全': '儘管你們的家庭正在經歷變動，但你對家庭的基礎仍感到滿足和安全。未來幾個月，你們將一起面對挑戰並度過這段時期，家庭的穩定將再次恢復。',
        '希望有更多時間陪伴家人': '家庭的變動使你希望有更多時間陪伴家人，以確保大家彼此支持。未來幾個月中，你將找到一些時間來與家人共度，這有助於減少壓力並增加聯繫。',
        '感到責任壓力較大': '你在面臨家庭變動時感到很大的責任壓力。未來幾個月中，你需要尋求其他家庭成員的幫助，共同分擔，這將有助於減輕你的負擔。',
        '希望家庭氛圍能更輕鬆': '你希望在面臨家庭變動時，能夠使家庭氛圍更輕鬆。未來幾個月，你將帶來一些新的活動或休閒計劃，讓家人放鬆並享受彼此的陪伴。',
      },
      '家庭 - 與家人相處和諧但有些小問題': {
        '感到滿足和安全': '你與家人的相處整體和諧，雖然有些小問題，但你仍然對家庭感到滿足和安全。未來幾個月中，這些小問題將逐漸得到解決，使家庭變得更為和睦。',
        '希望有更多時間陪伴家人': '你希望有更多時間陪伴家人，來解決目前存在的小問題。未來幾個月，你將找到一些機會來與家人增進感情，這將使小問題逐漸消失。',
        '感到責任壓力較大': '你在家庭中感受到一些責任壓力，這些壓力與家庭中的小問題有關。未來幾個月中，你將學會如何有效地分擔責任，讓家庭生活變得更為輕鬆。',
        '希望家庭氛圍能更輕鬆': '你希望家庭氛圍能更加輕鬆愉快，以減少目前的小摩擦。未來幾個月中，你將計劃一些活動，讓家人們一起享受更多輕鬆的時光。',
      },
      '家庭 - 與某位家庭成員存在摩擦': {
        '感到滿足和安全': '雖然你和某位家庭成員之間存在一些摩擦，但你對整體家庭感到滿足和安全。未來幾個月中，你們將找到方法來解決這些分歧，讓家庭更加和睦。',
        '希望有更多時間陪伴家人': '你希望有更多的時間陪伴家人，以改善目前與某位成員的摩擦。未來幾個月中，你將花更多時間來傾聽與理解，這將幫助修復關係。',
        '感到責任壓力較大': '你與某位家庭成員之間的摩擦讓你感到責任的壓力，但未來幾個月中，通過與其他成員的合作，你將找到減少壓力並化解矛盾的方法。',
        '希望家庭氛圍能更輕鬆': '你希望家庭中的摩擦能夠被化解，讓氛圍更加輕鬆。未來幾個月中，你將積極參與家庭活動，這將有助於改善關係，增進理解。',
      },
      '金錢 - 穩定，無需擔憂': {
        '有信心並持續改善': '你的財務狀況穩定且無需擔憂，未來幾個月，你將繼續保持這種穩定，並且可能找到一些新的投資機會來進一步改善你的財務狀況。',
        '希望有更多收入來源': '你目前的財務狀況穩定，但希望增加收入來源以提高生活品質。未來幾個月，你將發現一些新的收入機會，這將為你的生活帶來更多的財務自由。',
        '感到不安，希望有保障': '雖然你的財務狀況穩定，但你對未來有些不安，想要更強的保障。未來幾個月中，你可能會選擇增加儲蓄或購買保險來強化自己的安全感。',
        '正尋求改善財務的方法': '你的財務狀況穩定，但你仍然希望改善自己的理財策略。未來幾個月，你將學習更多理財知識或投資技巧，這些努力將幫助你進一步提升財務狀況。',
      },
      '金錢 - 正在存錢，努力達成目標': {
        '有信心並持續改善': '你目前正在努力存錢並對達成目標充滿信心。未來幾個月，你的存款將穩步增長，並幫助你接近設定的財務目標。',
        '希望有更多收入來源': '你正在存錢以達成目標，但希望能找到更多收入來源以加速目標的實現。未來幾個月，你將發現一些兼職或靈活收入機會，這將讓你的存款增長更快。',
        '感到不安，希望有保障': '你目前正在存錢，但對於達成目標的速度感到不安，希望能有更多保障。未來幾個月，你可能會調整預算或尋找新的方法來強化財務安全。',
        '正尋求改善財務的方法': '你正積極存錢，但也在尋找改善財務的方法。未來幾個月，你將學到一些新的理財策略或節省開支的方法，這將幫助你更快達成目標。',
      },
      '金錢 - 有些經濟壓力，但可控': {
        '有信心並持續改善': '你目前有些經濟壓力，但這些壓力是可控的，且你對未來的改善充滿信心。未來幾個月，你將找到更有效的理財方式，讓財務逐漸好轉。',
        '希望有更多收入來源': '你目前面臨一些經濟壓力，但希望找到更多收入來源來減輕負擔。未來幾個月，你可能會發現一些額外的工作機會，這將有效改善你的財務狀況。',
        '感到不安，希望有保障': '你目前的經濟壓力雖可控，但內心仍有些不安，渴望更多保障。未來幾個月，你將調整開支計劃或增加儲蓄，以使你感到更加安心。',
        '正尋求改善財務的方法': '你目前有些經濟壓力，正在尋求改善財務的方法。未來幾個月，你將學到一些新的理財技巧，這些技巧將幫助你更有效地管理和提升財務狀況。',
      },
      '金錢 - 遇到財務困難，需要解決': {
        '有信心並持續改善': '你目前面臨財務困難，但對未來充滿信心。未來幾個月，你將找到一些臨時收入或獲得外部支援，這將幫助你渡過難關並逐漸改善財務狀況。',
        '希望有更多收入來源': '你正面臨財務困難，希望找到更多收入來源以解決當前問題。未來幾個月，你將可能找到一些靈活的收入方式，這將幫助你改善目前的情況。',
        '感到不安，希望有保障': '你目前面臨財務困難，對未來感到不安。未來幾個月，你將尋求親友的幫助或社會支援，這將為你提供一些保障並減輕你的不安。',
        '正尋求改善財務的方法': '你目前正面臨財務困難，並正在尋找改善的方法。未來幾個月中，你將學習一些新的理財技巧，這些技巧將幫助你逐漸緩解財務壓力並改善狀況。',
      },
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _preloadManager = VideoPreloadManager();
    _initializeAllVideoControllers();


    _firstCardController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _secondCardController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _firstCardAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _firstCardController, curve: Curves.easeInOut));

    _secondCardAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _secondCardController, curve: Curves.easeInOut));

    _moveShrinkController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _moveAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(1.5, -1.5),
    ).animate(CurvedAnimation(parent: _moveShrinkController, curve: Curves.easeIn));

    _shrinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _moveShrinkController, curve: Curves.easeIn));

    _moveShrinkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _resetToInitial();
      }
    });

    _firstCardController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isCardMoving = false;
          _currentPage = 4;
        });
        _generateImage();
      }
    });

    _secondCardController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isCardMoving = false;
          _currentPage = 4;
        });
        _generateImage();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }


  @override
  void didPopNext() {
    final preloadManager = VideoPreloadManager();
    if (preloadManager.reverseTransitionController != null) {
      preloadManager.reverseTransitionController!.addListener(_onReverseTransitionComplete);
      preloadManager.reverseTransitionController!.play();
    }
    _initializeAllVideoControllers().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onReverseTransitionComplete() {
    final preloadManager = VideoPreloadManager();
    if (preloadManager.reverseTransitionController != null &&
        !preloadManager.reverseTransitionController!.value.isPlaying) {
      preloadManager.reverseTransitionController!.removeListener(_onReverseTransitionComplete);
      preloadManager.releaseVideo('assets/card_reverse.mp4');
      preloadManager.reverseTransitionController = null;

      if (mounted) { // 檢查是否仍然掛載
        // 播放背景影片或恢復該頁狀態
        _videoController?.play();
      }
    }
  }


  Future<void> _initializeAllVideoControllers() async {
    try {
      await _preloadManager.lazyLoadPageVideos('tarodcard');
      if (widget.transitionController != null) {
        await widget.transitionController!.seekTo(Duration.zero);
        widget.transitionController!.setLooping(false);
        widget.transitionController!.addListener(_onTransitionVideoComplete);
        widget.transitionController!.play();
      }

      _videoController = await _preloadManager.getController('assets/Dreamidle.mp4');
      if (_videoController != null) {
        await _videoController!.seekTo(Duration.zero);
        await _videoController!.setLooping(true);
        await _videoController!.setPlaybackSpeed(0.8);
        await _videoController!.setVolume(0.0);
        await _videoController!.pause();
        if (mounted) setState(() {});
      }

      _dreamTarodController = await _preloadManager.getController('assets/Dreamtarod.mp4');
      if (_dreamTarodController != null) {
        _dreamTarodController!.setLooping(false);
        _dreamTarodController!.addListener(_onDreamTarodComplete);
      }

      _dreamCardController = await _preloadManager.getController('assets/Dreamcard.mp4');
      if (_dreamCardController != null) {
        _dreamCardController!.setLooping(false);
        _dreamCardController!.addListener(_onDreamCardComplete);
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('初始化影片時出錯: $e');
    }
  }


  void _onTransitionVideoComplete() {
    if (widget.transitionController != null &&
        widget.transitionController!.value.position >= widget.transitionController!.value.duration) {
      widget.transitionController!.removeListener(_onTransitionVideoComplete);
      widget.transitionController?.pause();
      widget.transitionController?.seekTo(Duration.zero);

      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController?.seekTo(Duration.zero);
        _videoController?.play();
      }

      setState(() {
        _canRenderContent = true;
      });
    }
  }

  void _onReadSuccess() {
    if (_dreamTarodController != null && _dreamTarodController!.value.isInitialized) {
      _dreamTarodController!.play();
      setState(() {
        _isDreamTarodPlaying = true;
      });
    } else {
      print('Dreamtarod.mp4 尚未初始化');
    }
  }

// 確保每次需要顯示翻卡畫面時都呼叫此函式
  void _showFlipCard() {
    setState(() {
      _currentPage = 6;
      _canRenderContent = true;
      _showClickToFlipHint = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('請點擊卡片翻面'),
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  String getExplanationText(String? firstSelection, String? secondSelection) {
    if (firstSelection == null || secondSelection == null) {
      return '尚未選擇完整選項，無法顯示說明文字。';
    }

    // 構建映射鍵
    String mappingKey = '$firstSelection - $secondSelection';

    // 檢查映射是否存在
    if (!explanationMapping.containsKey(mappingKey)) {
      print('找不到映射鍵: $mappingKey'); // 添加調試信息
      return '無對應的說明文字。';
    }

    // 獲取對應情境集合
    Map<String, String> scenarios = explanationMapping[mappingKey]!;
    if (scenarios.isEmpty) {
      print('情境集合為空: $mappingKey'); // 添加調試信息
      return '未找到對應的說明文字。';
    }

    // 隨機選擇一個情境
    List<String> keys = scenarios.keys.toList();
    String randomKey = keys[Random().nextInt(keys.length)];

    // 返回對應的說明文字
    String explanation = scenarios[randomKey] ?? '未找到對應的說明文字。';
    print('選擇的說明文字: $explanation'); // 添加調試信息

    return explanation;
  }

// 在你的 State 類中使用這個方法
  String _getExplanationTextFromMapping() {
    return getExplanationText(_firstSelection, _secondSelection);
  }

  void _showExplanationOverlay() {
    String explanation = _getExplanationTextFromMapping();
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20.w),
          child: SingleChildScrollView(
            child: Text(
              explanation,
              style: TextStyle(color: Colors.black, fontSize: 16.sp),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    ).then((_) {
      // 底部彈窗關閉後才顯示上滑提示
      _showSwipeUpHint();
    });
  }

  void _showSwipeUpHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('向上滑動卡片以收進星盤', style: TextStyle(fontSize: 14.sp)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _onDreamTarodComplete() {
    if (_dreamTarodController != null &&
        _dreamTarodController!.value.position >= _dreamTarodController!.value.duration) {
      _dreamTarodController!.removeListener(_onDreamTarodComplete);

      if (!mounted) return; // 檢查是否仍然掛載

      setState(() {
        _isLoading = true; // 在 Dreamtarod.mp4 與 FlipCard 顯示前加上讀取提示
      });

      if (_dreamCardController != null && _dreamCardController!.value.isInitialized) {
        _dreamCardController!.seekTo(Duration.zero);
        _dreamCardController!.play();
      }
    }
  }



  void _onDreamCardComplete() {
    if (_dreamCardController != null &&
        _dreamCardController!.value.position >= _dreamCardController!.value.duration) {
      _dreamCardController!.removeListener(_onDreamCardComplete);

      if (!mounted) return; // 檢查是否仍然掛載

      setState(() {
        _isLoading = false;
      });

      // 添加延遲確保狀態已更新
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) { // 再次檢查是否仍然掛載
          _showFlipCard();
        }
      });
    }
  }



  Widget _buildScaledVideo(VideoPlayerController controller, {double scale = 1.0}) {
    if (!controller.value.isInitialized) {
      return Container();
    }

    return Transform.scale(
      scale: scale,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    return Stack(
      children: [
        if (_canRenderContent && _videoController != null)
          _buildScaledVideo(_videoController!),

        if (widget.transitionController != null &&
            widget.transitionController!.value.isInitialized &&
            widget.transitionController!.value.isPlaying)
          Opacity(
            opacity: 1.0,
            child: _buildScaledVideo(widget.transitionController!),
          ),

        if (_isDreamTarodPlaying && _dreamTarodController != null && _dreamTarodController!.value.isInitialized)
          _buildScaledVideo(_dreamTarodController!),

        Positioned(
          top: 20.h,
          left: 20.w,
          child: SafeArea(
            child: GestureDetector(
    onTap: () async {
    final preloadManager = VideoPreloadManager();
    bool reverseVideoLoaded = preloadManager.hasController('assets/card_reverse.mp4') &&
    preloadManager.isVideoLoaded('assets/card_reverse.mp4');

    if (!reverseVideoLoaded) {
    await preloadManager.lazyLoadPageVideos('tarodcard');
    // 'radio'是上一範例中預載頁面的名稱依據您的實際需求調整
    // 確保已載入 reverse transition 影片
    }

    VideoPlayerController? reverseTransitionController =
    await preloadManager.getController('assets/card_reverse.mp4');

    if (reverseTransitionController != null) {
    await reverseTransitionController.seekTo(Duration.zero);
    await reverseTransitionController.pause();
    preloadManager.reverseTransitionController = reverseTransitionController;
    Navigator.of(context).pop();
    } else {
    Navigator.of(context).pop();
    }
    },
    child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(10.r),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 24.r,
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: 20.h,
          right: 20.w,
          child: SafeArea(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isCardBookOpened = true;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(10.r),
                child: Icon(
                  Icons.book,
                  color: Colors.white,
                  size: 24.r,
                ),
              ),
            ),
          ),
        ),

        if (_isLoading)
          Center(
            child: Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100.w,
                    height: 100.w,
                    child: RiveAnimation.asset(
                      'assets/loading.riv',
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    '正在占卜中...',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  ),
                ],
              ),
            ),
          ),

        if (_canRenderContent && _currentPage <= 3)
          _buildCardBox(),

        if (_currentPage >= 6 && _generatedImages.isNotEmpty)
          _buildImageRevealLayer(),

        // 集卡冊區塊顯示
        if (_isCardBookOpened)
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5),
                      BlendMode.darken,
                    ),
                    child: Image.asset('assets/cardbook.JPG', fit: BoxFit.cover),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text("該區尚未開放", style: TextStyle(fontSize: 18.sp, color: Colors.black)),
                      ),
                      SizedBox(height: 20.h),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isCardBookOpened = false;
                          });
                        },
                        child: Text("返回", style: TextStyle(fontSize: 16.sp)),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_isMoving && _movingCardText != null)
          AnimatedAlign(
            alignment: _cardAlignment,
            duration: Duration(seconds: 1),
            curve: Curves.easeInOut,
            onEnd: () {
              setState(() {
                _isMoving = false;
                _movingCardText = null;
              });
              if (_currentPage == 1 || _currentPage == 2) {
                setState(() {
                  _currentPage = 3;
                });
              } else {
                _startAnalyzing();
              }
            },
            child: Container(
              width: 80.w,
              height: 60.h,
              decoration: BoxDecoration(
                color: _cardColorMap[_movingCardText!] ?? Colors.grey,
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Text(
                _movingCardText!,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardBoxContent() {
    if (_currentPage == 1 || _currentPage == 2) {
      return _buildFiveCardSelection(_currentPage)
          .animate()
          .fadeIn(duration: 500.ms)
          .slide(begin: const Offset(0, 0.1));
    } else if (_currentPage == 3) {
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '您選擇的兩張牌：',
              style: TextStyle(color: Colors.white, fontSize: 18.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              '$_firstSelection 與 $_secondSelection',
              style: TextStyle(color: Colors.white, fontSize: 16.sp),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: _startAnalyzing,
              child: Text('開始分析', style: TextStyle(fontSize: 16.sp)),
            ),
          ],
        ),
      );
    }

    return Container();
  }

  void _onCardTap(String option, int pageNumber) {
    if (pageNumber == 1) {
      setState(() {
        _firstSelection = option;
        _currentPage = 2;
      });
      _animateCard(option, pageNumber);
    } else if (pageNumber == 2) {
      setState(() {
        _secondSelection = option;
      });
      _animateCard(option, pageNumber);
    }
  }

  void _animateCard(String option, int pageNumber) {
    Alignment targetAlignment = pageNumber == 1 ? _firstTargetAlignment : _secondTargetAlignment;

    RenderBox? cardRenderBox = _cardKeys[option]?.currentContext?.findRenderObject() as RenderBox?;
    if (cardRenderBox == null) {
      print('無法找到卡牌的 RenderBox');
      return;
    }
    Offset cardPosition = cardRenderBox.localToGlobal(Offset.zero);

    RenderBox? targetRenderBox = (pageNumber == 1 ? _firstTargetKey : _secondTargetKey).currentContext?.findRenderObject() as RenderBox?;
    if (targetRenderBox == null) {
      print('無法找到目標的 RenderBox');
      return;
    }
    Offset targetPosition = targetRenderBox.localToGlobal(Offset.zero);

    double startLeft = cardPosition.dx;
    double startTop = cardPosition.dy;
    double endLeft = targetPosition.dx + (targetRenderBox.size.width - 80.w) / 2;
    double endTop = targetPosition.dy + (targetRenderBox.size.height - 60.h) / 2;

    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (context) => AnimatedCard(
        startPosition: Offset(startLeft, startTop),
        endPosition: Offset(endLeft, endTop),
        color: _cardColorMap[option] ?? Colors.grey,
        text: option,
        onCompleted: () {
          entry?.remove();
        },
      ),
    );

    Overlay.of(context)?.insert(entry);
  }

  Widget _buildFiveCardSelection(int pageNumber) {
    if (_firstSelection == '愛情') {
      secondRoundOptions = ['單身', '有穩定的伴侶', '處於曖昧中', '感情遇到困難'];
    } else if (_firstSelection == '事業') {
      secondRoundOptions = ['穩定就業', '正在尋找新工作', '希望事業有突破', '考慮轉職或創業'];
    } else if (_firstSelection == '人際') {
      secondRoundOptions = ['有密友並常常交流', '人際關係還可以，但希望拓展', '感到孤獨，缺乏交流', '與某人關係緊張，需要修復'];
    } else if (_firstSelection == '家庭') {
      secondRoundOptions = ['家庭穩定，感覺溫馨', '正在面臨家庭的變動或挑戰', '與家人相處和諧但有些小問題', '與某位家庭成員存在摩擦'];
    } else if (_firstSelection == '錢財') {
      secondRoundOptions = ['穩定，無需擔憂', '正在存錢，努力達成目標', '有些經濟壓力，但可控', '遇到財務困難，需要解決'];
    }

    List<String> currentOptions =
    (pageNumber == 1) ? firstRoundOptions : secondRoundOptions;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          pageNumber == 1 ? '最近的困擾面向？' : '當前狀況？',
          style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20.h),
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: List.generate(currentOptions.length, (index) {
            String option = currentOptions[index];
            if (!_cardKeys.containsKey(option)) {
              _cardKeys[option] = GlobalKey();
            }

            return GestureDetector(
              onTap: () {
                _onCardTap(option, pageNumber);
              },
              child: Container(
                key: _cardKeys[option],
                width: 80.w,
                height: 60.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cardColorMap[option] ?? Colors.grey,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCardBox() {
    return Positioned(
      top: _isAnalyzingAnimation
          ? 0.8.sh
          : 100.h,
      left: 20.w,
      right: 20.w,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        height: _isAnalyzingAnimation ? 0 : 0.6.sh,
        width: 1.sw - 40.w,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(_isAnalyzingAnimation ? 0 : 0.5),
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: _isAnalyzingAnimation
            ? const SizedBox()
            : Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentPage == 2)
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.r),
                        onPressed: () {
                          setState(() {
                            _currentPage = 1;
                            _firstSelection = null;
                            _secondSelection = null;
                          });
                        },
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    child: _buildCardBoxContent(),
                  ),
                  SizedBox(height: 20.h),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                '困擾面向',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Container(
                                key: _firstTargetKey,
                                width: 120.w,
                                height: 80.h,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white70,
                                    width: 2.w,
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                alignment: Alignment.center,
                                child: _firstSelection != null
                                    ? Container(
                                  width: 80.w,
                                  height: 60.h,
                                  decoration: BoxDecoration(
                                    color: _cardColorMap[_firstSelection!] ?? Colors.grey,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _firstSelection!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                                    : Text(
                                  '點擊卡片到此',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.sp,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '目前狀況',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Container(
                                key: _secondTargetKey,
                                width: 120.w,
                                height: 80.h,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white70,
                                    width: 2.w,
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                alignment: Alignment.center,
                                child: _secondSelection != null
                                    ? Container(
                                  width: 80.w,
                                  height: 60.h,
                                  decoration: BoxDecoration(
                                    color: _cardColorMap[_secondSelection!] ?? Colors.grey,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _secondSelection!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                                    : Text(
                                  '點擊卡片到此',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.sp,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_currentPage == 2 && _firstSelection != null && _secondSelection != null)
                        Padding(
                          padding: EdgeInsets.only(top: 20.h),
                          child: ElevatedButton(
                            onPressed: _startAnalyzing,
                            child: Text('占卜', style: TextStyle(fontSize: 16.sp)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 50.w, vertical: 15.h),
                              textStyle: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startAnalyzing() {
    if (_firstSelection == null || _secondSelection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請選擇兩張牌後再進行分析。', style: TextStyle(fontSize: 14.sp))),
      );
      return;
    }

    RenderBox? firstCardBox = _firstTargetKey.currentContext?.findRenderObject() as RenderBox?;
    RenderBox? secondCardBox = _secondTargetKey.currentContext?.findRenderObject() as RenderBox?;

    if (firstCardBox == null || secondCardBox == null) return;

    final screenHeight = 1.sh;
    final screenWidth = 1.sw;
    final targetY = screenHeight * 0.8;
    final targetX = screenWidth / 2;

    OverlayEntry? firstCardEntry;
    OverlayEntry? secondCardEntry;

    final firstCardPosition = firstCardBox.localToGlobal(Offset.zero);
    final secondCardPosition = secondCardBox.localToGlobal(Offset.zero);

    var animationsCompleted = 0;

    void onAnimationComplete() {
      animationsCompleted++;
      if (animationsCompleted == 2) {
        firstCardEntry?.remove();
        secondCardEntry?.remove();

        setState(() {
          _isAnalyzingAnimation = true;
        });

        Future.delayed(Duration(milliseconds: 500), () {
          _generateImage().then((_) {
            if (_dreamTarodController != null) {
              _dreamTarodController!.seekTo(Duration.zero);
              _dreamTarodController!.play();
            }
          });
        });
      }
    }

    firstCardEntry = OverlayEntry(
      builder: (context) => AnimatedCard(
        startPosition: Offset(firstCardPosition.dx, firstCardPosition.dy),
        endPosition: Offset(targetX - 40.w, targetY),
        color: _cardColorMap[_firstSelection!] ?? Colors.grey,
        text: _firstSelection!,
        onCompleted: onAnimationComplete,
      ),
    );

    secondCardEntry = OverlayEntry(
      builder: (context) => AnimatedCard(
        startPosition: Offset(secondCardPosition.dx, secondCardPosition.dy),
        endPosition: Offset(targetX - 40.w, targetY),
        color: _cardColorMap[_secondSelection!] ?? Colors.grey,
        text: _secondSelection!,
        onCompleted: onAnimationComplete,
      ),
    );

    Overlay.of(context)?.insertAll([firstCardEntry, secondCardEntry]);
  }

  Future<void> _generateImage() async {
    setState(() {
      _isLoading = true;
    });

    String key = '$_firstSelection - $_secondSelection';
    List<String>? prompts = promptMapping[key];
    if (prompts != null && prompts.isNotEmpty) {
      String prompt = prompts[Random().nextInt(prompts.length)];

      try {
        final response = await http.post(
          Uri.parse('$serverUrl/generate'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'prompt': prompt}),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['image'] != null) {
            setState(() {
              _generatedImages.add(base64Decode(responseData['image']));
              _isLoading = false;
            });

            setState(() {
              _currentPage = 5;
              _canRenderContent = false;
            });

            if (_videoController != null && _videoController!.value.isPlaying) {
              _videoController!.pause();
            }

            _onReadSuccess();
          } else {
            throw Exception('未生成圖片: ${responseData['error']}');
          }
        } else {
          throw Exception('生成圖片失敗: ${response.body}');
        }
      } catch (e) {
        print('生成圖片時出錯: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('錯誤: ${e.toString()}', style: TextStyle(fontSize: 14.sp))),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('找不到對應的提示詞', style: TextStyle(fontSize: 14.sp))),
      );
    }
  }

  Widget _buildImageRevealLayer() {
    if (_generatedImages.isEmpty || _dreamCardController == null || !_dreamCardController!.value.isInitialized) {
      return Container();
    }

    Uint8List imageBytes = _generatedImages.last;

    return Positioned.fill(
      child: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _moveShrinkController,
              builder: (context, child) {
                return Transform.translate(
                  offset: _moveAnimation.value * 1.sw,
                  child: Transform.scale(
                    scale: _shrinkAnimation.value,
                    child: FlipCard(
                      key: _flipCardKey,
                      flipOnTouch: false,
                      front: GestureDetector(
                        onTap: () {
                          _flipCardKey.currentState?.toggleCard();
                          _isFlipped = true;
                          _showClickToFlipHint = false;

                          if (!_showLongPressHint) {
                            _showLongPressHint = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('長按圖片查看含義', style: TextStyle(fontSize: 14.sp)),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            });
                          }
                        },
                        child: Image.asset(
                          'assets/card_back.png',
                          width: 500.w,
                          height: 600.h,
                          fit: BoxFit.cover,
                        ),
                      ),
                      back: GestureDetector(
                        onLongPress: _showExplanationOverlay,
                        child: Stack(
                          children: [
                            Image.memory(
                              imageBytes,
                              width: 500.w,
                              height: 600.h,
                              fit: BoxFit.cover,
                            ),
                            Positioned.fill(
                              child: Image.asset(
                                'assets/card_cover.png',
                                width: 500.w,
                                height: 600.h,
                                fit: BoxFit.cover,
                                color: Colors.black.withOpacity(0.3),
                                colorBlendMode: BlendMode.darken,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < -10) {
                _animateCardToTopRight();
              }
            },
          ),
        ],
      ),
    );
  }

  void _animateCardToTopRight() {
    _moveShrinkController.forward();

    _moveShrinkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentPage = 1;
        });
        _resetToInitial();
      }
    });
  }

  void _handleBackButton() async {
    Navigator.of(context).pop();
  }

  void _resetToInitial() {
    setState(() {
      _currentPage = 1;
      _firstSelection = null;
      _secondSelection = null;
      _generatedImages.clear();
      _isDreamTarodPlaying = false;
      _canRenderContent = true;
      _isAnalyzingAnimation = false;
      _isFlipped = false;
      _showClickToFlipHint = false;
      _showLongPressHint = false;
      _showSlideUpHint = false;
      _moveShrinkController.reset();
      secondRoundOptions = []; // 重置第二階段選項，確保流程重來時重新分配
      // 確保下一次重頭創建新的 FlipCard
      _flipCardKey = GlobalKey<FlipCardState>();
    });

    // 重置動畫相關狀態
    setState(() {
      _isMoving = false;
      _movingCardText = null;
    });

    // 將影片回到初始狀態
    if (_dreamTarodController != null) {
      _dreamTarodController!.pause();
      _dreamTarodController!.seekTo(Duration.zero);
      // 重新添加監聽器，確保第二次還會觸發 _onDreamTarodComplete
      _dreamTarodController!.removeListener(_onDreamTarodComplete);
      _dreamTarodController!.addListener(_onDreamTarodComplete);
    }

    if (_dreamCardController != null) {
      _dreamCardController!.pause();
      _dreamCardController!.seekTo(Duration.zero);
      // 重新添加監聽器，確保第二次還會觸發 _onDreamCardComplete
      _dreamCardController!.removeListener(_onDreamCardComplete);
      _dreamCardController!.addListener(_onDreamCardComplete);
    }

    if (_videoController != null && !_videoController!.value.isPlaying) {
      _videoController!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 在此初始化ScreenUtil（若在更上層初始化，則此處可省略）
    ScreenUtil.init(context, designSize: Size(375, 812), minTextAdapt: true);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildVideoLayer(),
        ],
      ),
    );
  }
}

class AnimatedCard extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final Color color;
  final String text;
  final VoidCallback onCompleted;

  const AnimatedCard({
    Key? key,
    required this.startPosition,
    required this.endPosition,
    required this.color,
    required this.text,
    required this.onCompleted,
  }) : super(key: key);

  @override
  _AnimatedCardState createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _animation = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.endPosition,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    _controller.addListener(() {
      setState(() {});
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _animation.value.dx,
      top: _animation.value.dy,
      child: Transform.scale(
        scale: _scaleAnimation.value,
        child: Container(
          width: 80.w,
          height: 60.h,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(12.r),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}


