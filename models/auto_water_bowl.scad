// Gecko Automation - Automatic Water Bowl
// Parametric OpenSCAD model for a shallow leopard gecko water bowl
// with controlled overflow and a simple tubing guide.
//
// Design goals:
// - shallow enough for easy drinking
// - overflow notch fixes water level
// - external spillway directs overflow toward substrate / humid hide side
// - inlet guide holds silicone tube aimed tangentially for a gentle swirl rinse
// - prints without supports in the default orientation
//
// Suggested print settings:
// - PETG recommended
// - 0.2mm layer height
// - 4-5 perimeters
// - 100% infill, or seal afterward with food-safe epoxy if needed
// - if using PLA, keep away from hotter basking zones

$fn = 64;

/* [Main dimensions] */
outer_len = 92;
outer_wid = 72;
outer_h = 18;
corner_r = 12;
wall = 3;
floor_thickness = 3;

/* [Water geometry] */
water_depth = 8;          // final water depth above floor
overflow_width = 18;
overflow_guard = 5;       // keeps notch away from corners
spillway_len = 28;
spillway_drop = 6;
spillway_wall = 2;

/* [Tube guide] */
tube_od = 6;              // common silicone tubing OD
clip_wall = 3;
clip_height_above_rim = 14;
clip_width = 16;
clip_depth = 10;
zip_tie_slot_w = 3.5;
zip_tie_slot_h = 8;

/* [Optional base] */
add_base_pad = true;
base_pad_thickness = 1.6;
base_pad_margin = 6;

module rounded_rect_2d(len, wid, r) {
    hull() {
        for (x = [-len/2 + r, len/2 - r])
            for (y = [-wid/2 + r, wid/2 - r])
                translate([x, y]) circle(r = r);
    }
}

module bowl_shell() {
    difference() {
        // Outer shell
        linear_extrude(height = outer_h)
            rounded_rect_2d(outer_len, outer_wid, corner_r);

        // Inner cavity
        translate([0, 0, floor_thickness])
            linear_extrude(height = outer_h)
                rounded_rect_2d(
                    outer_len - 2*wall,
                    outer_wid - 2*wall,
                    max(1, corner_r - wall)
                );

        // Overflow notch on the right side
        overflow_bottom_z = floor_thickness + water_depth;
        translate([
            outer_len/2 - wall - 0.01,
            0,
            overflow_bottom_z + (outer_h - overflow_bottom_z)/2
        ])
            cube([
                wall + 0.5,
                overflow_width,
                outer_h - overflow_bottom_z + 0.1
            ], center = true);
    }
}

module spillway() {
    // Support-free stepped spillway.
    // A gentle staircase prints cleanly without supports and still guides overflow out.
    start_x = outer_len/2 - wall;
    width = overflow_width + 10;
    steps = 4;
    step_run = spillway_len / steps;
    top_start_z = floor_thickness + water_depth - 0.6;
    step_drop = spillway_drop / steps;

    for (i = [0 : steps - 1]) {
        step_h = max(1.2, top_start_z - i * step_drop);
        step_w = width + i * 1.5;
        translate([start_x + step_run * (i + 0.5), 0, step_h / 2])
            cube([step_run + 0.2, step_w, step_h], center = true);
    }
}

module tube_guide() {
    // External rear-left guide, kept out of the drinking area.
    guide_x = -outer_len/2 - clip_depth/2 - 1;
    guide_y = -outer_wid/2 + wall + clip_width/2 + 8;
    guide_z = outer_h;
    guide_h = clip_height_above_rim;

    difference() {
        // body outside the bowl wall
        translate([guide_x, guide_y, guide_z + guide_h/2])
            cube([clip_depth, clip_width, guide_h], center = true);

        // half-round tube saddle at the top
        translate([guide_x - clip_depth/2 - 0.01, guide_y, guide_z + guide_h - tube_od/2 - 1])
            rotate([0, 90, 0])
                cylinder(h = clip_depth + 0.2, d = tube_od + 0.8, center = false);

        // opening to turn saddle into an open notch
        translate([guide_x + 1.5, guide_y, guide_z + guide_h - tube_od/2 - 1])
            cube([clip_depth, tube_od + 4, tube_od + 4], center = true);

        // zip tie slots
        for (zslot = [guide_z + guide_h*0.40, guide_z + guide_h*0.68]) {
            translate([guide_x, guide_y, zslot])
                cube([clip_depth + 0.2, zip_tie_slot_w, zip_tie_slot_h], center = true);
        }
    }

    // tie the guide back into the bowl wall with a printable gusset
    hull() {
        translate([guide_x + clip_depth/2, guide_y, outer_h + 1])
            cube([1, clip_width, 2], center = true);
        translate([-outer_len/2 + wall/2, guide_y, outer_h - 5])
            cube([wall, clip_width, 2], center = true);
    }
}
module base_pad() {
    if (add_base_pad) {
        translate([0, 0, -base_pad_thickness])
            linear_extrude(height = base_pad_thickness)
                rounded_rect_2d(
                    outer_len + 2*base_pad_margin,
                    outer_wid + 2*base_pad_margin,
                    corner_r + base_pad_margin/2
                );
    }
}

module assembly() {
    union() {
        base_pad();
        bowl_shell();
        spillway();
        tube_guide();
    }
}

assembly();
