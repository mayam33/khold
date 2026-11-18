extends Node

signal language_changed(language: String)

var language := "en"

const ENGLISH := {
	"خُلد — مغامرة الحفر": "Beaver Explorer — Underground Adventure",
	"خُلد": "Beaver Explorer",
	"مغامرة الحفر": "Underground Adventure",
	"مغامرة تحت الأرض": "Underground Adventure",
	"ملّ القندس من الحفر قرب النهر، فانطلق ليستكشف ما تحت الأرض.": "The beaver grew bored of digging beside rivers and set out to explore underground.",
	"احفر، اجمع الثمار، واحذر الصخور.": "Bored of digging by the river, a curious beaver ventures underground to explore.",
	"العب": "Play",
	"محرر المراحل": "Level Editor",
	"مراحل الإنترنت": "Community Levels",
	"الإعدادات": "Settings",
	"مفتوح المصدر • رخصة MIT • Godot 4": "Open source • MIT License • Godot 4",
	"الإصدار 1.1.0": "Version 1.1.0",
	"رجوع": "Back",
	"المراحل": "Levels",
	"مرحلة جديدة": "New Level",
	"مراحل اللعبة": "Campaign",
	"مراحلي": "My Levels",
	"مرحلة محفوظة على الجهاز": "levels saved on this device",
	"لم تصنع مرحلة بعد. اضغط «مرحلة جديدة» وارسم فكرتك، ثم اختبرها واحفظها.": "You have not made a level yet. Choose “New Level,” build it, test it, and save it.",
	"لم تُلعب بعد": "Not played yet",
	"أول حفرة": "First Burrow",
	"صخور في الطريق": "Rocks Ahead",
	"ممرات ضيقة": "Narrow Passages",
	"تحت الصخور": "Under the Rocks",
	"الغرفة المغلقة": "The Locked Room",
	"الجسر": "The Bridge",
	"الحلقة الحجرية": "Stone Ring",
	"المتاهة": "The Maze",
	"الصخور المتساقطة": "Falling Rocks",
	"القبو": "The Underground",
	"بقلم %s": "by %s",
	"حذف": "Delete",
	"تعديل": "Edit",
	"لعب": "Play",
	"تحديث": "Refresh",
	"عنوان الخادم": "Server URL",
	"اتصال": "Connect",
	"جاهز.": "Ready.",
	"جارٍ الاتصال بالخادم…": "Connecting to server…",
	"تم الاتصال • %d مرحلة منشورة.": "Connected • %d published levels.",
	"مراحل منشورة": "Published Levels",
	"لا توجد مراحل من الخادم الآن. شغّل خادم المراحل ثم اضغط «تحديث».": "No levels are available right now. Start the level server, then choose Refresh.",
	"مراحل نزّلتها": "Downloaded Levels",
	"كل مرحلة تنزّلها تُحفظ هنا للعب دون اتصال.": "Downloaded levels are saved here for offline play.",
	"نشر مراحلي": "Publish My Levels",
	"اصنع مرحلة في المحرر أولًا، ثم عد إلى هنا لنشرها.": "Create a level in the editor, then return here to publish it.",
	"قيّم المرحلة": "Rate Level",
	"تقييم": "Rate",
	"إبلاغ": "Report",
	"إلغاء": "Cancel",
	"نشر": "Publish",
	"نشر نسخة": "Publish Update",
	"منشورة مسبقًا": "Already Published",
	"محفوظة على الجهاز": "Saved on This Device",
	"شكراً لتقييمك.": "Thanks for your rating.",
	"إبلاغ عن مرحلة": "Report Level",
	"هل تريد الإبلاغ عن «%s»؟\nتُراجع البلاغات وتُخفى المراحل المخالفة.": "Report “%s”? Reports are reviewed and rule-breaking levels may be hidden.",
	"حذف التنزيل": "Delete Download",
	"حذف النسخة المحفوظة من «%s»؟": "Delete the saved copy of “%s”?",
	"القائمة": "Menu",
	"مرحلة": "Level",
	"اختبار": "Test",
	"الحركات 0": "Moves 0",
	"الثمار 0/0": "Fruit 0/0",
	"الهدف —": "Goal —",
	"اسحب فوق الأرض للحفر، أو استخدم الأسهم.": "Swipe to dig, or use the direction buttons.",
	"تراجع": "Undo",
	"إعادة": "Restart",
	"تعذر تحميل المرحلة.": "Could not load the level.",
	"لا يوجد ما يمكن التراجع عنه.": "Nothing to undo.",
	"خذ نفسًا. الأرض لن تهرب.": "Take a breath. The ground can wait.",
	"متابعة": "Resume",
	"خروج": "Exit",
	"إيقاف مؤقت": "Paused",
	"نجحت المرحلة في الاختبار!": "Level test complete!",
	"العودة للمحرر": "Back to Editor",
	"المرحلة التالية": "Next Level",
	"قائمة المراحل": "Level List",
	"أحسنت!": "Well done!",
	"سحقتك الصخرة!": "Crushed by a rock!",
	"سقطت صخرة عليك. جرّب طريقًا آخر، أو تراجع خطوة.": "A falling rock hit you. Try another route or undo a move.",
	"الحركات": "Moves",
	"الثمار": "Fruit",
	"الهدف": "Goal",
	"الأدوات — ارسم بإصبعك على اللوحة": "Tools — draw on the board with your finger",
	"تراب": "Dirt",
	"فراغ": "Empty",
	"صخر": "Rock",
	"فولاذ": "Steel",
	"فاكهة": "Fruit",
	"مخرج": "Exit",
	"لاعب": "Player",
	"اختبار المرحلة": "Test Level",
	"لوحة جديدة": "New Board",
	"مرحلتي": "My Level",
	"اسم المرحلة": "Level Name",
	"لوحة جديدة جاهزة.": "New board ready.",
	"تم حفظ «%s».": "Saved “%s”.",
	"خروج دون حفظ": "Exit Without Saving",
	"لديك تعديلات غير محفوظة. هل تريد الخروج؟": "You have unsaved changes. Do you want to leave?",
	"سيتم مسح كل ما رسمته. هل تريد المتابعة؟": "This will clear your board. Continue?",
	"الأبعاد غير مدعومة.": "These dimensions are not supported.",
	"المخرج أو إحدى الثمار غير قابلة للوصول. افتح طريقًا.": "The exit or a fruit is unreachable. Open a path.",
	"المخرج مقفل — اجمع كل الثمار أولًا.": "The exit is locked — collect all fruit first.",
	"فُتح المخرج! الطريق إلى الأسفل جاهز.": "The exit is open! The way down is clear.",
	"المؤثرات الصوتية": "Sound Effects",
	"نغمات الحفر والجمع والنجاح": "Sounds for digging, collecting, and winning",
	"الاهتزاز": "Haptics",
	"لمسات خفيفة على الجوال": "Light feedback on mobile",
	"اسم اللاعب": "Player Name",
	"يظهر مع المراحل التي تنشرها.": "Shown with levels you publish.",
	"حفظ": "Save",
	"حُفظ الاسم.": "Name saved.",
	"حُفظ عنوان الخادم.": "Server URL saved.",
	"خادم المراحل": "Level Server",
	"الخادم السحابي جاهز افتراضيًا.\nللتجربة محليًا استخدم http://127.0.0.1:8787 أو عنوان الكمبيوتر على شبكة Wi-Fi.": "The cloud server is ready by default.\nFor local testing, use http://127.0.0.1:8787 or your computer’s Wi-Fi address.",
	"عن اللعبة": "About the Game",
	"خُلد لعبة حفر بكسل أصلية، مفتوحة المصدر برخصة MIT. كل الرسومات والأصوات تُرسم وتُولّد بالكود داخل المشروع، ولا تحتوي اللعبة على أصول فنية منسوخة من أي لعبة أخرى.": "Beaver Explorer is an original underground puzzle game, released under the MIT License. Character art is based on the supplied beaver sprite sheet.",
	"صُنعت بـ Godot 4. الخط: Almarai برخصة SIL Open Font License. أسلوب اللعب مستلهم من ألعاب الحفر الكلاسيكية مع تصميم ومحتوى أصليين.": "Made with Godot 4. The game takes inspiration from classic digging puzzles and has its own levels and mechanics.",
	"مسح التقدم": "Reset Progress",
	"سيُمسح أفضل نتيجة ونجوم كل المراحل الأساسية. المراحل التي صنعتها لن تُحذف.": "Best scores and stars for campaign levels will be cleared. Your own levels will stay.",
	"امسح": "Reset",
	"تم مسح التقدم.": "Progress reset.",
	"ترخيص Godot": "Godot License",
	"رخصة الخط": "Font License",
	"اللغة": "Language",
	"حجم العرض": "Display Size",
	"إظهار أسهم التحكم": "Show Direction Buttons",
	"كبّر أو صغّر واجهة اللعبة.": "Make the game interface larger or smaller.",
	"English": "English",
	"العربية": "العربية",
	"صغير": "Small",
	"عادي": "Normal",
	"كبير": "Large",
	"قندس": "Beaver",
	"يمكنك إخفاؤها واستخدام السحب أو لوحة المفاتيح.": "Hide them to use swipes or the keyboard instead.",
	"لا يستطيع القندس الصعود إلى فراغ.": "The beaver cannot climb into open air.",
	"Beaver Explorer مغامرة قندس استكشف فيها الأنفاق تحت الأرض. رسوم الشخصية مبنية على ورقة الرسوم التي زودنا بها اللاعب.": "Beaver Explorer follows a curious beaver exploring underground tunnels. The character animations use the supplied sprite sheet.",
	"صُنعت بـ Godot 4. أسلوب اللعب يستلهم ألعاب الحفر الكلاسيكية مع مراحل ومحتوى أصليين.": "Made with Godot 4, with original levels inspired by classic digging puzzles.",
	"صغر أو كبّر واجهة اللعبة.": "Make the game interface smaller or larger.",
	"شكرًا لتقييمك.": "Thanks for your rating.",
	"شكرًا، تم استلام البلاغ.": "Thanks, your report was received.",
	"المرحلة المرسلة غير صالحة.": "The submitted level is invalid.",
	"تعذر التنزيل.": "Could not download the level.",
	"تعذر إرسال التقييم.": "Could not submit the rating.",
	"تعذر إرسال البلاغ.": "Could not submit the report.",
	"تعذر النشر.": "Could not publish the level.",
	"تم نشر المرحلة!": "Level published!",
	"جارٍ تنزيل المرحلة…": "Downloading level…",
	"جارٍ إرسال التقييم…": "Submitting rating…",
	"جارٍ إرسال البلاغ…": "Submitting report…",
	"بيانات المرحلة غير مكتملة.": "Level data is incomplete.",
	"أبعاد المرحلة غير مدعومة.": "These level dimensions are not supported.",
	"صفوف المرحلة غير متساوية الطول.": "The level rows are not the same length.",
	"المرحلة تحتوي على أكثر من نقطة بداية.": "The level has more than one player start.",
	"المرحلة تحتوي على أكثر من مخرج.": "The level has more than one exit.",
	"أضف نقطة بداية للاعب.": "Add a player start.",
	"أضف مخرجًا للمرحلة.": "Add an exit.",
	"أضف ثمرة واحدة على الأقل.": "Add at least one fruit.",
	"رد غير مفهوم من الخادم.": "The server returned an unreadable response.",
	"فشل الاتصال بالخادم. تأكد من تشغيله ومن العنوان.": "Could not reach the server. Check that it is running and that the URL is correct.",
	"بقلم اللاعب": "by the player",
}

func _ready() -> void:
	language = String(Store.settings.get("language", "en"))
	_apply_locale()

func set_language(code: String) -> void:
	var next := "ar" if code.to_lower().begins_with("ar") else "en"
	if language == next:
		return
	language = next
	Store.set_setting("language", language)
	_apply_locale()
	language_changed.emit(language)

func _apply_locale() -> void:
	TranslationServer.set_locale(language)

func translate_text(source: String) -> String:
	if language == "ar":
		return source
	if ENGLISH.has(source):
		return String(ENGLISH[source])
	if source.begins_with("الحركات: "):
		return "Moves: " + source.trim_prefix("الحركات: ")
	if source.begins_with("الحركات "):
		return "Moves " + source.trim_prefix("الحركات ")
	if source.begins_with("الثمار: "):
		return "Fruit: " + source.trim_prefix("الثمار: ")
	if source.begins_with("الثمار "):
		return "Fruit " + source.trim_prefix("الثمار ")
	if source.begins_with("الهدف: "):
		var goal := source.trim_prefix("الهدف: ")
		goal = goal.replace(" حركة", " moves")
		return "Goal: " + goal
	if source.begins_with("الهدف "):
		return "Goal " + source.trim_prefix("الهدف ")
	if source.begins_with("مرحلة: "):
		return "Level: " + source.trim_prefix("مرحلة: ")
	if source.begins_with("أفضل نتيجة: "):
		return "Best: " + source.trim_prefix("أفضل نتيجة: ")
	if source.begins_with("أفضل "):
		return "Best " + source.trim_prefix("أفضل ")
	if source.begins_with("بقلم "):
		var author_detail := source.trim_prefix("بقلم ")
		author_detail = author_detail.replace(" ثمار", " fruit").replace(" • أفضل ", " • Best ").replace(" • محفوظة على الجهاز", " • saved locally")
		return "by " + author_detail
	if source.begins_with("الأداة: "):
		return "Tool: " + translate_text(source.trim_prefix("الأداة: "))
	if source.begins_with("حركات: "):
		return "Moves: " + source.trim_prefix("حركات: ")
	if source.begins_with("الهدف: "):
		return "Goal: " + source.trim_prefix("الهدف: ")
	if source.begins_with("ثمار: "):
		var split := source.split(" • المقاس ", false, 1)
		if split.size() == 2:
			return "Fruit: " + String(split[0]).trim_prefix("ثمار: ") + " • Size " + String(split[1])
	if source.begins_with("التقييم "):
		return "Rating " + source.trim_prefix("التقييم ").replace(" لعبة", " plays")
	if source.begins_with("منشورة مسبقًا"):
		return "Already published"
	if source.begins_with("تم تنزيل «"):
		return source.replace("تم تنزيل «", "Downloaded “").replace("». ", "”. ").replace("».", "”.")
	if source.begins_with("تم حفظ «"):
		return source.replace("تم حفظ «", "Saved “").replace("». ", "”. ").replace("».", "”.")
	if source.begins_with("نُشرت «"):
		return source.replace("نُشرت «", "Published “").replace("» بنجاح.", "” successfully.")
	if source.begins_with("تم الاتصال • "):
		return source.replace("تم الاتصال • ", "Connected • ").replace(" مرحلة منشورة.", " published levels.")
	if source.begins_with("تعذر بدء الاتصال (رمز "):
		return "Could not start connection (code " + source.trim_prefix("تعذر بدء الاتصال (رمز ").trim_suffix(").") + ")."
	if source.begins_with("خطأ من الخادم ("):
		return source.replace("خطأ من الخادم (", "Server error (")
	if source.begins_with("تعذر الاتصال. — "):
		return "Offline — downloaded levels remain available, and publishing can resume when the server is back."
	if source.ends_with(" مرحلة محفوظة على الجهاز"):
		var count := source.get_slice(" ", 0)
		if count.is_valid_int():
			return count + " levels saved on this device"
	return source

func set_node_text(node: Object, property: StringName, source: String) -> void:
	var meta := StringName("_beaver_source_" + String(property))
	if not node.has_meta(meta):
		node.set_meta(meta, source)
	else:
		node.set_meta(meta, source)
	node.set(property, translate_text(source))

func translate_tree(root: Node) -> void:
	if root == null:
		return
	_translate_node(root)
	for child in root.get_children():
		translate_tree(child)

func _translate_node(node: Node) -> void:
	if node is Label:
		var alignment_meta := &"_beaver_original_alignment"
		if not node.has_meta(alignment_meta):
			node.set_meta(alignment_meta, node.horizontal_alignment)
		var original_alignment := int(node.get_meta(alignment_meta))
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if language == "en" and original_alignment != HORIZONTAL_ALIGNMENT_CENTER else original_alignment
	for property in [&"text", &"placeholder_text", &"title", &"dialog_text", &"ok_button_text", &"cancel_button_text"]:
		if not _has_property(node, property):
			continue
		var meta := StringName("_beaver_source_" + String(property))
		var source := String(node.get_meta(meta, node.get(property)))
		node.set_meta(meta, source)
		node.set(property, translate_text(source))

func _has_property(object: Object, property: StringName) -> bool:
	for info in object.get_property_list():
		if StringName(info.name) == property:
			return true
	return false
