class_name UIStyle
extends RefCounted
## Design tokens: the one place colours, fonts, spacing and motion live.
## See docs/UI_PLAN.md. build_theme() turns these into the project Theme;
## components read the same constants for anything drawn in code.

# --- Motion -------------------------------------------------------------------
## Global animation speed multiplier (fast mode = 2, tests = 20+).
static var speed: float = 1.0

const DUR_FAST := 0.12
const DUR_BASE := 0.22
const DUR_SLOW := 0.4

# --- Surfaces & text ----------------------------------------------------------
const BG_DEEP := Color("#120F17")
const BG := Color("#1B1722")
const PANEL := Color("#262030")
const PANEL_HI := Color("#342B42")
const OUTLINE := Color("#0A080D")
const TEXT := Color("#F2ECE4")
const TEXT_DIM := Color("#A69FB0")
const TEXT_DISABLED := Color("#6B6473")
const GOLD := Color("#F6B43C")

# --- Semantic colours ---------------------------------------------------------
const DAMAGE := Color("#FF5A4A")
const POISON := Color("#7BC950")
const BURN := Color("#F07A2A")
const BLOCK := Color("#6CB8F0")
const HEAL := Color("#5BE08A")
const ENERGY := Color("#F6D743")
const BUFFED := Color("#7CFC8A")
const DEBUFFED := Color("#FF6B6B")
const HP_BAR := Color("#D9473E")
const HP_BAR_BLOCKED := Color("#4C8FD6")
const HP_GHOST := Color("#F5D0C8")

const TYPE_COLORS := {
	CardData.CardType.ATTACK: Color("#7A3530"),
	CardData.CardType.SKILL: Color("#2F4F73"),
	CardData.CardType.POWER: Color("#5A3A78"),
	CardData.CardType.STATUS: Color("#4A4A4A"),
	CardData.CardType.CURSE: Color("#3A1F3A"),
}
const RARITY_COLORS := {
	CardData.Rarity.STARTER: Color("#9AA0A6"),
	CardData.Rarity.COMMON: Color("#9AA0A6"),
	CardData.Rarity.UNCOMMON: Color("#4FA3E0"),
	CardData.Rarity.RARE: Color("#E8B34A"),
	CardData.Rarity.SPECIAL: Color("#B07CE0"),
}

# --- Type & spacing -----------------------------------------------------------
const FONT_DISPLAY_PATH := "res://assets/fonts/cinzel/Cinzel-Bold.woff2"
const FONT_BODY_PATH := "res://assets/fonts/nunito/Nunito-Regular.woff2"
const FONT_BOLD_PATH := "res://assets/fonts/nunito/Nunito-Bold.woff2"
const FONT_HEAVY_PATH := "res://assets/fonts/nunito/Nunito-ExtraBold.woff2"

const SIZE_SMALL := 14
const SIZE_BODY := 16
const SIZE_LARGE := 20
const SIZE_H2 := 26
const SIZE_H1 := 36
const SIZE_BANNER := 64

const RADIUS_SMALL := 6
const RADIUS_PANEL := 12
const RADIUS_CARD := 14

static var _fonts: Dictionary = {}


static func dur(seconds: float) -> float:
	return seconds / maxf(speed, 0.01)


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		var font: Font = load(path) if ResourceLoader.exists(path) else null
		_fonts[path] = font if font != null else ThemeDB.fallback_font
	return _fonts[path]


static func display_font() -> Font:
	return _font(FONT_DISPLAY_PATH)


static func body_font() -> Font:
	return _font(FONT_BODY_PATH)


static func bold_font() -> Font:
	return _font(FONT_BOLD_PATH)


static func heavy_font() -> Font:
	return _font(FONT_HEAVY_PATH)


## Adds the engine's default font as a fallback so glyphs outside the latin
## subsets (arrows, symbols) still render. Called once at startup.
static func install_font_fallbacks() -> void:
	for path in [FONT_DISPLAY_PATH, FONT_BODY_PATH, FONT_BOLD_PATH, FONT_HEAVY_PATH]:
		var font := _font(path)
		if font is FontFile and font.fallbacks.is_empty():
			font.fallbacks = [ThemeDB.fallback_font]


static func type_color(type: CardData.CardType) -> Color:
	return TYPE_COLORS.get(type, PANEL)


static func rarity_color(rarity: CardData.Rarity) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[CardData.Rarity.COMMON])


static func damage_color(type: DamageInfo.Type) -> Color:
	match type:
		DamageInfo.Type.POISON:
			return POISON
		DamageInfo.Type.BURN:
			return BURN
	return DAMAGE


static func box(color: Color, radius: int = RADIUS_PANEL, border_color: Color = Color.TRANSPARENT,
		border: int = 0, padding: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border_color
	sb.set_border_width_all(border)
	sb.set_content_margin_all(padding)
	sb.anti_aliasing = true
	return sb


## Adds a text outline so numbers stay readable over any art.
static func outline_label(label: Label, size: int = 6, color: Color = OUTLINE) -> void:
	label.add_theme_constant_override("outline_size", size)
	label.add_theme_color_override("font_outline_color", color)


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = SIZE_BODY

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", display_font())
	t.set_font_size("font_size", "TitleLabel", SIZE_H1)
	t.set_color("font_color", "TitleLabel", GOLD)
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", display_font())
	t.set_font_size("font_size", "HeadingLabel", SIZE_H2)
	t.set_type_variation("DimLabel", "Label")
	t.set_color("font_color", "DimLabel", TEXT_DIM)
	t.set_font_size("font_size", "DimLabel", SIZE_SMALL)

	# Rich text
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", body_font())
	t.set_font("bold_font", "RichTextLabel", bold_font())
	t.set_font_size("normal_font_size", "RichTextLabel", SIZE_BODY)
	t.set_font_size("bold_font_size", "RichTextLabel", SIZE_BODY)

	# Buttons
	t.set_font("font", "Button", bold_font())
	t.set_font_size("font_size", "Button", SIZE_LARGE)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_stylebox("normal", "Button", box(PANEL_HI, RADIUS_PANEL, OUTLINE, 2, 14))
	t.set_stylebox("hover", "Button", box(PANEL_HI.lightened(0.12), RADIUS_PANEL, GOLD.darkened(0.3), 2, 14))
	t.set_stylebox("pressed", "Button", box(PANEL, RADIUS_PANEL, GOLD, 2, 14))
	t.set_stylebox("disabled", "Button", box(PANEL.darkened(0.2), RADIUS_PANEL, OUTLINE, 2, 14))
	var focus := box(Color.TRANSPARENT, RADIUS_PANEL, GOLD, 3, 14)
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	t.set_stylebox("focus", "Button", focus)

	# Primary (gold) button, e.g. End Turn
	t.set_type_variation("PrimaryButton", "Button")
	t.set_font("font", "PrimaryButton", display_font())
	t.set_font_size("font_size", "PrimaryButton", SIZE_LARGE)
	t.set_color("font_color", "PrimaryButton", BG_DEEP)
	t.set_color("font_hover_color", "PrimaryButton", BG_DEEP)
	t.set_color("font_focus_color", "PrimaryButton", BG_DEEP)
	t.set_color("font_pressed_color", "PrimaryButton", BG_DEEP)
	t.set_color("font_disabled_color", "PrimaryButton", TEXT_DISABLED)
	t.set_stylebox("normal", "PrimaryButton", box(GOLD, RADIUS_PANEL, GOLD.darkened(0.45), 3, 14))
	t.set_stylebox("hover", "PrimaryButton", box(GOLD.lightened(0.15), RADIUS_PANEL, GOLD.darkened(0.3), 3, 14))
	t.set_stylebox("pressed", "PrimaryButton", box(GOLD.darkened(0.15), RADIUS_PANEL, GOLD.darkened(0.5), 3, 14))
	t.set_stylebox("disabled", "PrimaryButton", box(PANEL, RADIUS_PANEL, OUTLINE, 3, 14))
	var primary_focus := focus.duplicate()
	primary_focus.border_color = Color.WHITE
	t.set_stylebox("focus", "PrimaryButton", primary_focus)

	# Panels
	t.set_stylebox("panel", "PanelContainer", box(PANEL, RADIUS_PANEL, OUTLINE, 2, 16))
	t.set_stylebox("panel", "Panel", box(PANEL, RADIUS_PANEL, OUTLINE, 2, 16))
	t.set_type_variation("BarPanel", "PanelContainer")
	t.set_stylebox("panel", "BarPanel", box(Color(BG_DEEP, 0.85), 0, OUTLINE, 0, 10))

	# Tooltips (engine fallback tooltips; the TooltipLayer uses the same look)
	t.set_stylebox("panel", "TooltipPanel", box(Color(BG_DEEP, 0.96), RADIUS_SMALL, GOLD.darkened(0.4), 2, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", SIZE_BODY)

	# Scrollbars
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color(PANEL, 0.6), RADIUS_SMALL, Color.TRANSPARENT, 0, 4))
		t.set_stylebox("grabber", bar, box(PANEL_HI.lightened(0.15), RADIUS_SMALL, Color.TRANSPARENT, 0, 4))
		t.set_stylebox("grabber_highlight", bar, box(GOLD.darkened(0.2), RADIUS_SMALL, Color.TRANSPARENT, 0, 4))
		t.set_stylebox("grabber_pressed", bar, box(GOLD, RADIUS_SMALL, Color.TRANSPARENT, 0, 4))
	return t
