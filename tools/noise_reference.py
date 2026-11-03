"""Human-authored edge-grid scenes and an independent rectangle sampler.

The expected foreground is explicitly drawn separately from injected noise.
It does not call, parse or reproduce the production row-selection state machine.
"""
import numpy as np


def ring(a, x0, x1, y0, y1):
    a[y0:y1 + 1, x0] = a[y0:y1 + 1, x1] = 1
    a[y0, x0:x1 + 1] = a[y1, x0:x1 + 1] = 1


def plus(a, x0, x1, y0, y1):
    a[(y0 + y1)//2, x0:x1 + 1] = 1
    a[y0:y1 + 1, (x0 + x1)//2] = 1


def projected_boxes(a):
    occupied = np.flatnonzero(a.any(axis=0))
    if not len(occupied):
        return []
    groups = np.split(occupied, np.flatnonzero(np.diff(occupied) >= 3) + 1)
    result = []
    for group in groups:
        y, _ = np.nonzero(a[:, group[0]:group[-1] + 1])
        result.append(tuple(map(int, (group[0], group[-1], y.min(), y.max()))))
    return result


def sampling_box(boxes, i, size, pad=1):
    x0, x1, y0, y1 = boxes[i]
    left, right = max(0, x0-pad), min(size-1, x1+pad)
    if i:
        # Assign each gap cell to the closer character; ties to its left one.
        candidates = [x for x in range(size) if x-boxes[i-1][1] > x0-x]
        left = max(left, min(candidates))
    if i+1 < len(boxes):
        candidates = [x for x in range(size) if x-x1 <= boxes[i+1][0]-x]
        right = min(right, max(candidates))
    return left, right, max(0, y0-pad), min(size-1, y1+pad)


def normalize(foreground, box):
    x0, x1, y0, y1 = box
    patch = np.asarray(foreground[y0:y1+1, x0:x1+1], bool)
    height, width = patch.shape
    side = max(height, width)
    square = np.zeros((side, side), bool)
    top, left = (side-height)//2, (side-width)//2
    square[top:top+height, left:left+width] = patch
    out = np.zeros((28, 28), np.uint8)
    # Direct boolean rectangles, independently of RTL address generation.
    for y in range(20):
        ya, yb = y*side//20, max(y*side//20+1, (y+1)*side//20)
        for x in range(20):
            xa, xb = x*side//20, max(x*side//20+1, (x+1)*side//20)
            out[y+4, x+4] = square[ya:yb, xa:xb].any()
    return out


def cases():
    all_cases = []

    def add(name, clean, injected=None, labels=(0, 11, 0), reject=None,
            expression_valid=True, noise_min=0, tags=()):
        noisy = clean.copy() if injected is None else np.maximum(clean, injected)
        boxes = projected_boxes(clean) if reject is None else []
        if reject is None:
            assert len(boxes) == len(labels), (name, boxes, labels)
            assert 3 <= len(boxes) <= 5
        all_cases.append(dict(name=name, grid=noisy, foreground=clean,
            boxes=boxes, labels=labels, expected_expression_valid=expression_valid,
            reject=reject, noise_min=noise_min, tags=list(tags)))

    def base(g=64):
        a = np.zeros((g, g), np.uint8)
        ring(a, 6, 17, 20, 43)
        a[31:33, 27:39] = 1
        ring(a, 47, 58, 20, 43)
        return a

    a = base()
    add('clean_three_short_minus', a, tags=('baseline', 'minus'))
    for name, x, y, w, h in (
        ('point_above_same_x', 10, 6, 3, 3),
        ('point_below_same_x', 10, 52, 3, 3),
        ('point_between_left_and_minus', 21, 30, 3, 3),
        ('point_between_minus_and_right', 41, 31, 3, 3),
        ('point_on_search_border_outside_row', 0, 3, 3, 3),
        ('point_on_search_border_inside_row', 0, 30, 3, 3),
        ('point_in_digit_hole', 10, 29, 3, 3),
        ('larger_compact_point_inside_row', 20, 29, 5, 5),
    ):
        n = np.zeros_like(a); n[y:y+h, x:x+w] = 1
        add(name, a, n, noise_min=1, tags=('point', 'at_least_8_cells'))

    n = np.zeros_like(a)
    for x, y in ((0, 30), (21, 30), (41, 31), (10, 6), (50, 53), (30, 5)):
        n[y:y+3, x:x+3] = 1
    add('six_noise_components_before_character_limit', a, n, noise_min=6,
        tags=('candidate_capacity', 'not_truncated'))

    # Cropping to x=5 must not admit the point at x=3..5. The glyph has no
    # foreground on its left boundary at the point's height, so CCL is separate.
    seven = np.zeros_like(a)
    seven[20:22, 6:18] = 1; seven[20:44, 16:18] = 1
    seven[31:33, 27:39] = 1; ring(seven, 47, 58, 20, 43)
    n = np.zeros_like(a); n[33:36, 3:6] = 1
    add('noise_inside_four_pixel_crop_border', seven, n,
        noise_min=1, tags=('ownership', 'crop_border'))

    one = np.zeros_like(a)
    one[20:44, 6] = 1
    one[32, 27:35] = 1; ring(one, 47, 58, 20, 43)
    add('thin_one_and_one_cell_high_minus', one, labels=(1, 11, 0),
        tags=('thin_one', 'minus', 'exact_8_cell_operator'))

    # A sufficiently long interior stroke is deliberately retained.
    bar = a.copy(); bar[31, 8:16] = 1
    add('disconnected_interior_horizontal_stroke', bar,
        tags=('disconnected_stroke', 'ownership'))

    double = np.zeros_like(a)
    double[20:44, 5:7] = 1; double[20:44, 8:10] = 1
    double[32, 27:35] = 1; ring(double, 47, 58, 20, 43)
    add('one_empty_column_between_normal_strokes', double,
        tags=('projection_gap', 'disconnected_stroke'))

    four = np.zeros_like(a)
    ring(four, 2, 9, 21, 42); four[21:43, 16:18] = 1
    plus(four, 26, 38, 26, 38); ring(four, 47, 58, 21, 42)
    add('clean_four_characters', four, labels=(0, 1, 10, 0), tags=('baseline',))

    five = np.zeros_like(a)
    for x in (2, 13, 43, 54):
        ring(five, x, x+7, 21, 42)
    plus(five, 27, 37, 27, 37)
    add('clean_five_characters', five, labels=(0, 0, 10, 0, 0), tags=('baseline',))
    n = np.zeros_like(a); n[4:7, 30:33] = 1
    add('five_characters_with_sixth_raw_candidate', five, n,
        labels=(0, 0, 10, 0, 0), noise_min=1, tags=('candidate_capacity',))

    # It is correct to keep the extra normal digit: 2+39 is legal. Never
    # silently delete its 9 to reconstruct the user's presumed old 2+3.
    legal_four = np.zeros_like(a)
    ring(legal_four, 2, 9, 21, 42)
    plus(legal_four, 16, 26, 27, 37)
    ring(legal_four, 34, 42, 21, 42); ring(legal_four, 51, 60, 21, 42)
    add('legal_two_digit_operand_keeps_all_four_tokens', legal_four,
        labels=(2, 10, 3, 9), tags=('extra_normal_digit', 'not_truncated'))

    multiop = np.zeros_like(a)
    ring(multiop, 2, 9, 21, 42); plus(multiop, 15, 23, 28, 36)
    ring(multiop, 29, 36, 21, 42); plus(multiop, 42, 50, 28, 36)
    ring(multiop, 56, 63-1, 21, 42)
    add('two_operators_kept_then_parser_rejects', multiop,
        labels=(2, 10, 3, 10, 4), expression_valid=False,
        tags=('extra_operator', 'parser_rejection'))

    six = np.zeros_like(a)
    for x in (1, 11, 34, 44, 54):
        ring(six, x, x+6, 21, 42)
    plus(six, 22, 30, 28, 36)
    add('six_normal_characters_are_not_truncated', six,
        reject=(2,), expression_valid=False, tags=('extra_normal_digit', 'over_five'))

    edge = four.copy(); edge[:, 2:10] = 0; ring(edge, 0, 9, 21, 42)
    add('selected_character_touching_border_rejected', edge,
        reject=(3,), expression_valid=False, tags=('border_rejection',))
    dots = np.zeros_like(a)
    for x in (7, 28, 49): dots[30:33, x:x+3] = 1
    add('no_main_line_of_digits', dots, reject=(1, 5), expression_valid=False,
        tags=('no_line',))
    add('blank_rejected', np.zeros_like(a), reject=(1, 5),
        expression_valid=False, tags=('blank',))
    two = np.zeros_like(a); ring(two, 6, 17, 20, 43); ring(two, 47, 58, 20, 43)
    add('only_two_digits_rejected', two, reject=(5,),
        expression_valid=False, tags=('too_few',))

    big = np.zeros((96, 96), np.uint8)
    ring(big, 8, 25, 25, 64); big[44:46, 42:58] = 1; ring(big, 74, 87, 25, 64)
    big[44, 13:21] = 1  # Eight cells, tiny relative to H40, but line-like.
    add('large_scale_disconnected_tiny_bar_retained', big,
        tags=('disconnected_stroke', 'relative_scale'))

    # A small but valid-height 1 must not disappear into the dot classifier.
    mixed = np.zeros((96, 96), np.uint8)
    ring(mixed, 5, 20, 25, 64); plus(mixed, 31, 45, 38, 52)
    ring(mixed, 55, 70, 25, 64); mixed[42:50, 82] = 1
    add('minimum_height_extra_one_is_kept', mixed,
        labels=(2, 10, 3, 1), tags=('mixed_size', 'extra_normal_digit', 'not_truncated'))
    mixed_zero = np.zeros((96, 96), np.uint8)
    ring(mixed_zero, 5, 20, 25, 64); plus(mixed_zero, 31, 45, 38, 52)
    ring(mixed_zero, 55, 70, 25, 64); ring(mixed_zero, 80, 85, 42, 49)
    add('minimum_height_extra_zero_is_kept', mixed_zero,
        labels=(2, 10, 3, 0), tags=('mixed_size', 'extra_normal_digit', 'not_truncated'))

    tall_overlap = np.zeros((96, 96), np.uint8)
    ring(tall_overlap, 6, 17, 40, 63); tall_overlap[51:53, 40:55] = 1
    ring(tall_overlap, 76, 87, 40, 63)
    n = np.zeros_like(tall_overlap); n[2:35, 10:12] = 1
    add('off_row_long_object_only_touches_band_edge', tall_overlap, n,
        noise_min=1, tags=('row_localization', 'same_x', 'band_edge'))

    two_rows = np.zeros((96, 96), np.uint8)
    for yy in (10, 60):
        ring(two_rows, 6, 17, yy, yy+19); two_rows[yy+9:yy+11, 40:55] = 1
        ring(two_rows, 76, 87, yy, yy+19)
    add('two_equally_supported_rows_are_ambiguous', two_rows,
        reject=(1,), expression_valid=False, tags=('ambiguous_row',))

    crowded = np.zeros((96, 96), np.uint8)
    ring(crowded, 6, 17, 45, 72); crowded[58:60, 40:55] = 1
    ring(crowded, 76, 87, 45, 72)
    positions = [(x, y) for y in (3, 10, 17) for x in range(3, 90, 7)]
    n = np.zeros_like(crowded)
    for x, y in positions[:29]: n[y:y+3, x:x+3] = 1
    add('exact_32_component_capacity_after_noise', crowded, n,
        noise_min=29, tags=('component_capacity_boundary',))
    n = np.zeros_like(crowded)
    for x, y in positions[:30]: n[y:y+3, x:x+3] = 1
    add('33_components_rejected_without_truncation', crowded, n,
        reject=(4,), expression_valid=False, tags=('component_overflow',))

    high = np.zeros((192, 192), np.uint8)
    ring(high, 135, 146, 137, 164); high[150:152, 155:169] = 1
    ring(high, 177, 188, 137, 164)
    n = np.zeros_like(high); n[120:123, 138:141] = 1
    n[150:153, 149:152] = 1; n[180:183, 187:190] = 1
    add('production_grid_high_coordinates_noise', high, n,
        noise_min=3, tags=('high_coordinates', 'production_grid'))
    return all_cases
