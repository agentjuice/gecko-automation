// Mealworm Hopper + Servo Gate for Gecko Automation
// Designed for MG996R servo + 3D printing (PLA/PETG)
// 
// Concept:
//   - Cylindrical hopper stores mealworms in bran/oats
//   - Funnel narrows to dispensing channel at bottom
//   - Rotating disc gate (servo-driven) has a notch that portions out worms
//   - Vibration motor mount on hopper wall prevents bridging
//   - Dispensing chute exits at an angle for gravity drop into feeding dish
//
// Print settings: 0.2mm layer, 15-20% infill, no supports needed
// All dimensions in mm

/* [Hopper] */
hopper_diameter = 60;       // Inner diameter of hopper cylinder
hopper_height = 100;        // Height of hopper body
hopper_wall = 2.5;          // Wall thickness
funnel_height = 25;         // Height of funnel transition
funnel_exit_diameter = 25;  // Narrows to this at the gate

/* [Gate] */
gate_diameter = 30;         // Rotating disc diameter
gate_thickness = 6;         // Disc thickness (needs to hold worms)
gate_notch_width = 15;      // Width of the dispensing notch
gate_notch_depth = 12;      // Depth of notch (radial)
gate_clearance = 0.4;       // Clearance between disc and housing

/* [Servo Mount] */
// MG996R dimensions
servo_width = 20;
servo_height = 40.5;
servo_depth = 38.5;
servo_shaft_offset = 10;    // Shaft center from edge

/* [Dispensing Chute] */
chute_length = 40;
chute_angle = 45;           // Angle from vertical
chute_inner = 20;           // Inner diameter

/* [Vibration Motor Mount] */
vibe_motor_diameter = 10;   // Coin motor diameter
vibe_motor_depth = 3;       // Recess depth

/* [Lid] */
lid_lip = 3;                // Overlap lip depth

// ============================================
// MODULES
// ============================================

module hopper_body() {
    difference() {
        union() {
            // Main cylinder
            cylinder(d=hopper_diameter + hopper_wall*2, h=hopper_height, $fn=80);
            
            // Funnel section below
            translate([0, 0, -funnel_height])
                cylinder(
                    d1=funnel_exit_diameter + hopper_wall*2,
                    d2=hopper_diameter + hopper_wall*2,
                    h=funnel_height, $fn=80
                );
        }
        
        // Hollow out the cylinder
        translate([0, 0, hopper_wall])
            cylinder(d=hopper_diameter, h=hopper_height + 1, $fn=80);
        
        // Hollow out the funnel
        translate([0, 0, -funnel_height + hopper_wall])
            cylinder(
                d1=funnel_exit_diameter,
                d2=hopper_diameter,
                h=funnel_height + 1, $fn=80
            );
        
        // Gate opening at bottom of funnel
        translate([0, 0, -funnel_height - 1])
            cylinder(d=funnel_exit_diameter, h=hopper_wall + 2, $fn=60);
    }
}

module gate_housing() {
    housing_outer = gate_diameter + hopper_wall*2 + gate_clearance*2;
    housing_height = gate_thickness + hopper_wall*2;
    
    translate([0, 0, -funnel_height - housing_height]) {
        difference() {
            // Outer housing
            cylinder(d=housing_outer, h=housing_height, $fn=80);
            
            // Disc cavity
            translate([0, 0, hopper_wall])
                cylinder(
                    d=gate_diameter + gate_clearance*2,
                    h=gate_thickness + 0.2, $fn=80
                );
            
            // Inlet from funnel (top)
            translate([0, 0, housing_height - hopper_wall - 0.1])
                cylinder(d=funnel_exit_diameter, h=hopper_wall + 0.2, $fn=60);
            
            // Outlet to chute (bottom, offset to side)
            translate([gate_diameter/4, 0, -0.1])
                cylinder(d=chute_inner, h=hopper_wall + 0.2, $fn=40);
            
            // Servo shaft hole (side entry)
            translate([0, 0, hopper_wall + gate_thickness/2])
                rotate([0, 90, 0])
                    cylinder(d=6, h=housing_outer/2 + 10, $fn=30);
        }
    }
}

module gate_disc() {
    // The rotating disc with a portioning notch
    // Print separately!
    difference() {
        cylinder(d=gate_diameter, h=gate_thickness, $fn=80);
        
        // Portioning notch — worms fall into this pocket
        translate([gate_diameter/4 - gate_notch_width/2, -gate_notch_width/2, -0.1])
            cube([gate_notch_width, gate_notch_width, gate_thickness + 0.2]);
        
        // Servo shaft hole (center)
        // MG996R shaft is 25T spline, ~5.8mm
        translate([0, 0, -0.1])
            cylinder(d=5.8, h=gate_thickness + 0.2, $fn=6); // hex for grip
    }
    
    // Servo horn adapter nub
    translate([0, 0, gate_thickness])
        difference() {
            cylinder(d=10, h=2, $fn=30);
            translate([0, 0, -0.1])
                cylinder(d=5.8, h=2.2, $fn=6);
        }
}

module servo_mount() {
    // MG996R mounting bracket on side of gate housing
    housing_height = gate_thickness + hopper_wall*2;
    mount_z = -funnel_height - housing_height;
    
    translate([gate_diameter/2 + hopper_wall + gate_clearance, -servo_width/2, mount_z]) {
        difference() {
            // Mount plate
            cube([servo_depth + 4, servo_width + 4, housing_height]);
            
            // Servo body cutout
            translate([2, 2, -0.1])
                cube([servo_depth, servo_width, housing_height + 0.2]);
            
            // Mounting screw holes (MG996R pattern)
            for (y = [servo_width/2 + 2]) {
                for (x = [5, servo_depth - 1]) {
                    translate([x, y, housing_height/2])
                        rotate([0, 0, 0])
                            cylinder(d=3.2, h=housing_height + 1, center=true, $fn=20);
                }
            }
        }
    }
}

module dispensing_chute() {
    housing_height = gate_thickness + hopper_wall*2;
    chute_z = -funnel_height - housing_height;
    
    translate([gate_diameter/4, 0, chute_z]) {
        rotate([0, chute_angle, 0]) {
            difference() {
                cylinder(d=chute_inner + hopper_wall*2, h=chute_length, $fn=40);
                translate([0, 0, -0.1])
                    cylinder(d=chute_inner, h=chute_length + 0.2, $fn=40);
            }
        }
    }
}

module vibe_motor_mount() {
    // Recessed pocket on hopper wall for coin vibration motor
    translate([hopper_diameter/2 + hopper_wall - vibe_motor_depth, 0, hopper_height * 0.6])
        rotate([0, 90, 0])
            difference() {
                cylinder(d=vibe_motor_diameter + 4, h=vibe_motor_depth + 2, $fn=30);
                translate([0, 0, 2])
                    cylinder(d=vibe_motor_diameter, h=vibe_motor_depth + 0.1, $fn=30);
                // Wire channel
                translate([-2, 0, -0.1])
                    cylinder(d=3, h=vibe_motor_depth + 3, $fn=15);
            }
}

module lid() {
    // Snap-on lid for filling
    translate([0, 0, hopper_height + 5]) {
        difference() {
            union() {
                // Top plate
                cylinder(d=hopper_diameter + hopper_wall*2 + 4, h=hopper_wall, $fn=80);
                // Inner lip
                translate([0, 0, -lid_lip])
                    cylinder(d=hopper_diameter - 0.4, h=lid_lip, $fn=80);
            }
            // Ventilation holes (mealworms need air)
            for (a = [0:60:359]) {
                translate([hopper_diameter/4 * cos(a), hopper_diameter/4 * sin(a), -0.1])
                    cylinder(d=3, h=hopper_wall + 0.2, $fn=15);
            }
        }
    }
}

// ============================================
// ASSEMBLY
// ============================================

// Uncomment the parts you want to render/export:

// Full assembly view
module assembly() {
    color("SteelBlue", 0.8) hopper_body();
    color("SlateGray", 0.8) gate_housing();
    color("Orange", 0.9) servo_mount();
    color("Peru", 0.7) dispensing_chute();
    color("Red", 0.8) vibe_motor_mount();
    color("LightBlue", 0.7) lid();
    
    // Show gate disc in position (for visualization)
    housing_height = gate_thickness + hopper_wall*2;
    color("Gold", 0.9)
        translate([0, 0, -funnel_height - housing_height + hopper_wall])
            gate_disc();
}

// === Render full assembly (default) ===
assembly();

// === Export individual parts (uncomment one at a time) ===
// hopper_body();
// gate_housing();
// gate_disc();        // Print separately!
// servo_mount();
// dispensing_chute();
// lid();
