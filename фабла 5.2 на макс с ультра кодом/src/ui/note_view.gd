class_name NoteView
extends Control
## Чтение записки: лист бумаги по центру. Мир при этом не останавливается.

signal closed

var is_open := false
var _dim: ColorRect
var _paper: PanelContainer
var _text: Label
var _after: Label
var _foot: Label
var _sb: StyleBoxTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_paper = PanelContainer.new()
	_sb = StyleBoxTexture.new()
	_sb.texture = Kit.tex("res://tex/paper")
	_sb.content_margin_left = 46
	_sb.content_margin_right = 40
	_sb.content_margin_top = 38
	_sb.content_margin_bottom = 40
	_paper.add_theme_stylebox_override("panel", _sb)
	add_child(_paper)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 560
	_paper.add_child(_text)
	_after = Ui.label("", 22, Color(0.72, 0.76, 0.82))
	_after.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_after)
	_foot = Ui.label("E — закрыть", 19, Ui.DIM)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_foot)
	visible = false


func open(id: String, args: Array = []) -> void:
	if not T.NOTES.has(id):
		return
	var n: Dictionary = T.NOTES[id]
	var style := String(n.get("style", "print"))
	var txt := String(n.text)
	if not args.is_empty():
		txt = txt % args
	_text.text = txt
	var grid := style == "hand" or style == "mine"
	_sb.texture = Kit.tex("res://tex/paper_grid" if grid else "res://tex/paper")
	match style:
		"hand":
			_text.add_theme_font_override("font", Kit.font("hand"))
			_text.add_theme_font_size_override("font_size", 24)
			_text.add_theme_color_override("font_color", Color(0.1, 0.13, 0.4))
		"mine":
			_text.add_theme_font_override("font", Kit.font("hand"))
			_text.add_theme_font_size_override("font_size", 24)
			_text.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
		"type":
			_text.add_theme_font_override("font", Kit.font("type"))
			_text.add_theme_font_size_override("font_size", 21)
			_text.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		_:
			_text.add_theme_font_override("font", Kit.font("ui"))
			_text.add_theme_font_size_override("font_size", 23)
			_text.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_after.text = String(n.get("after", ""))
	_paper.reset_size()
	visible = true
	is_open = true
	Snd.play("paper", -6.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Snd.play("paper", -9.0, 1.15)
	closed.emit()


func _process(_dt: float) -> void:
	if not visible:
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_dim.size = size
	var ps := _paper.get_combined_minimum_size()
	_paper.size = ps
	_paper.position = Vector2((size.x - ps.x) * 0.5, maxf(20.0, (size.y - ps.y) * 0.5 - 30.0))
	_after.size = Vector2(minf(size.x * 0.7, 760.0), 60)
	_after.position = Vector2((size.x - _after.size.x) * 0.5, _paper.position.y + ps.y + 14)
	_foot.size = Vector2(200, 30)
	_foot.position = Vector2(size.x - 230, size.y - 46)
