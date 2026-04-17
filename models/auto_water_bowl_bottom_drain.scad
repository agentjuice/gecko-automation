// Gecko Automation - Automatic Water Bowl (Bottom Drain Variant)
//
// Concept:
// - shallow gecko water bowl
// - bottom drain hole for a real bulkhead / push fitting
// - removable standpipe inside bowl sets water level
// - pedestal base hides the drain hardware and provides rear tube exit
// - external tube guide keeps inlet line out of the drinking area
//
// Notes:
// - The bowl is meant to be used with a REAL gasketed fitting, not a raw printed thread.
// - The drain hole diameter is parametric. Adjust it to match your hardware.
// - The standpipe is a visual / printable insert concept. Final fit will depend on the fitting you choose.

$fn = 72;

/* [Main bowl] */
outer_len = 92;
outer_wid = 72;
outer_h = 18;
corner_r = 12;
wall = 3;
floor_thickness = 3;
water_depth = 8;

/* [Drain / standpipe] */
drain_hole_d = 12;         // adjust to actual bulkhead / fitting
standpipe_outer_d = 10;
standpipe_inner_d = 6;
standpipe_height = 8;      // sets water level inside bowl
standpipe_guard_d = 18;
standpipe_guard_h = 12;
standpipe_slot_w = 2.2;
standpipe_slot_count = 8;

/* [Base pedestal] */
pedestal_h = 10;
pedestal_margin = 6;
pedestal_wall = 3;
tube_exit_w = 12;          // rear notch for drain tube

/* [Tube guide] */
tube_od = 6;
clip_width = 16;
clip_depth = 10;
clip_height_above_rim = 14;
zip_tie_slot_w = 3.5;
zip_tie_slot_h = 8;

show_bowl = true;
show_standpipe = true;
show_assembly = true;

module rounded_rect_2d(len, wid, r) {
    hull() {
        for (x = [-len/2 + r, len/2 - r])
            for (y = [-wid/2 + r, wid/2 - r])
                translate([x, y]) circle(r = r);
    }
}

module bowl_body() {
    drain_y = -10;  // rear-center-ish so outlet can hide behind bowl

    difference() {
        union() {
            // main bowl shell
            difference() {
                linear_extrude(height = outer_h)
                    rounded_rect_2d(outer_len, outer_wid, corner_r);

                translate([0, 0, floor_thickness])
                    linear_extrude(height = outer_h)
                        rounded_rect_2d(
                            outer_len - 2*wall,
                            outer_wid - 2*wall,
                            max(1, corner_r - wall)
                        );
            }

            // pedestal base below bowl
            translate([0, 0, -pedestal_h])
                difference() {
                    linear_extrude(height = pedestal_h)
                        rounded_rect_2d(
                            outer_len + 2*pedestal_margin,
                            outer_wid + 2*pedestal_margin,
                            corner_r + pedestal_margin/2
                        );

                    // hollow center cavity for bulkhead / tubing
                    translate([0, 0, pedestal_wall])
                        linear_extrude(height = pedestal_h)
                            rounded_rect_2d(
                                outer_len + 2*pedestal_margin - 2*pedestal_wall,
                                outer_wid + 2*pedestal_margin - 2*pedestal_wall,
                                corner_r + max(1, pedestal_margin/2 - pedestal_wall/2)
                            );

                    // rear exit notch for drain tube
                    translate([0, -(outer_wid/2 + pedestal_margin) + 0.1, pedestal_h/2])
                        cube([tube_exit_w, pedestal_wall + 2, pedestal_h + 0.2], center = true);
                }

            // external tube guide
            tube_guide();
        }

        // drain hole through bowl floor and pedestal top
        translate([0, drain_y, -pedestal_h - 0.1])
            cylinder(d = drain_hole_d, h = outer_h + pedestal_h + 0.2);
    }
}

module standpipe_insert() {
    // Simple standpipe with slotted guard and short lower spigot.
    spigot_d = drain_hole_d - 0.5;
    spigot_h = floor_thickness + 2;
    body_h = standpipe_height;

    difference() {
        union() {
            // lower spigot that sits in the drain fitting / hole
            cylinder(d = spigot_d, h = spigot_h);

            // main standpipe body
            translate([0, 0, spigot_h])
                cylinder(d = standpipe_outer_d, h = body_h);

            // slotted guard around standpipe top
            translate([0, 0, spigot_h])
                cylinder(d = standpipe_guard_d, h = standpipe_guard_h);
        }

        // through bore
        translate([0, 0, -0.1])
            cylinder(d = standpipe_inner_d, h = spigot_h + body_h + standpipe_guard_h + 0.2);

        // side slots in guard
        for (i = [0 : standpipe_slot_count - 1]) {
            rotate([0, 0, i * 360 / standpipe_slot_count])
                translate([standpipe_guard_d/2 - 1.8, 0, spigot_h + standpipe_guard_h/2])
                    cube([3.5, standpipe_slot_w, standpipe_guard_h - 3], center = true);
        }
    }
}

module tube_guide() {
    guide_x = -outer_len/2 - clip_depth/2 - 1;
    guide_y = -outer_wid/2 + wall + clip_width/2 + 8;
    guide_z = outer_h;
    guide_h = clip_height_above_rim;

    difference() {
        translate([guide_x, guide_y, guide_z + guide_h/2])
            cube([clip_depth, clip_width, guide_h], center = true);

        translate([guide_x - clip_depth/2 - 0.01, guide_y, guide_z + guide_h - tube_od/2 - 1])
            rotate([0, 90, 0])
                cylinder(h = clip_depth + 0.2, d = tube_od + 0.8, center = false);

        translate([guide_x + 1.5, guide_y, guide_z + guide_h - tube_od/2 - 1])
            cube([clip_depth, tube_od + 4, tube_od + 4], center = true);

        for (zslot = [guide_z + guide_h*0.40, guide_z + guide_h*0.68]) {
            translate([guide_x, guide_y, zslot])
                cube([clip_depth + 0.2, zip_tie_slot_w, zip_tie_slot_h], center = true);
        }
    }

    hull() {
        translate([guide_x + clip_depth/2, guide_y, outer_h + 1])
            cube([1, clip_width, 2], center = true);
        translate([-outer_len/2 + wall/2, guide_y, outer_h - 5])
            cube([wall, clip_width, 2], center = true);
    }
}

module assembly() {
    if (show_bowl) bowl_body();

    if (show_standpipe) {
        // Show standpipe dropped into the drain hole
        translate([0, -10, floor_thickness])
            color("gold")
                standpipe_insert();
    }
}

module print_layout() {
    if (show_bowl)
        bowl_body();

    if (show_standpipe)
        translate([outer_len/2 + 20, 0, 0])
            standpipe_insert();
}

if (show_assembly)
    assembly();
else
    print_layout();
