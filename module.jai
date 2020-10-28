// Jai-INI
// INI file reader for Jai
// Smári McCarthy <smari@smarimccarthy.is>

INI :: struct {
    case_sensitive      : bool;
    allow_hash_comments : bool;
    duplicate_behavior  : INIDupeBehavior;
    sections            : [..]*INISection;
}

INISection :: struct {
    dead       : bool;
    name       : string;
    props      : [..]*INIProperty;
}

INIProperty :: struct {
    key     : string;
    value   : string;
}

INIDupeBehavior :: enum { NONE; IGNORE; OVERRIDE; ABORT; }

INIValue :: union {
    val_string  : string;
    val_int     : s64;
    val_float   : float64;
}

ini_read_file :: (filename: string) -> *INI, bool {
    ini := New(INI);
    init(ini);
    cur_section, _ := ini_add_section(ini, "DEFAULT");

    handler: Text_File_Handler;
    handler.comment_character = #char ";";
    handler.strip_comments_from_ends_of_lines = false;
    handler.do_version_number = false;

    defer deinit(*handler);

    start_file(*handler, "INI file", filename, "INI reader", false);
    if handler.failed return ini, false;

    while true {
        line, foundline := consume_next_line(*handler);
        if !foundline break;
        if ini.allow_hash_comments && line[0] == #char "#" {
            continue;
        }
        if line[0] == #char "[" && line[line.count-1] == #char "]" {
            line.data += 1;
            line.count -= 2;
            section, result := ini_add_section(ini, line);
            if result == {
                case .ABORT; return ini, false;
                case .IGNORE; continue;
                case .OVERRIDE; cur_section = section;
            }
        } else {
            found, key, value := split_by_character_from_right(line, #char "=");
            if !found {
                print("Error in line %: '%'.\n", handler.line_number, line);
                return ini, false;
            } else {
                ini_add_value(ini, cur_section, key, value);
            }
        }

    }
    return ini, true;
}

ini_dump_string :: (ini: *INI) -> string {
    s := New(String_Builder);
    for sec:ini.sections {
        if sec.props.count == 0 || sec.dead continue;
        append(s, tprint("[%]\n", sec.name));
        for prop:sec.props {
            append(s, tprint("%=%\n", prop.key, prop.value));
        }
        append(s, tprint("\n"));
    }
    return builder_to_string(s);
}

ini_write_file :: (ini: *INI, filename: string) -> bool {
    return write_entire_file(filename, ini_dump_string(ini));
}

init :: (ini: *INI) {
    ini.case_sensitive = false;
    ini.allow_hash_comments = true;
    ini.duplicate_behavior = .OVERRIDE;
}

deinit :: (ini: *INI) {
    for s:ini.sections deinit(s);
    free(ini);
}

deinit :: (section: *INISection) {
    for p:section.props deinit(p);
    free(section.name);
    free(section);
}

deinit :: (prop: *INIProperty) {
    free(prop.key);
    free(prop.value);
    free(prop);
}

ini_add_section :: (ini: *INI, name: string, get_or_create := false) -> *INISection, INIDupeBehavior {
    if !ini.case_sensitive && name != "DEFAULT" {
        to_lower(name);
    }
    for s:ini.sections {
        if s.name == name {
            if get_or_create {
                return s, .OVERRIDE;
            } else if ini.duplicate_behavior == {
                case .ABORT; return null, .ABORT;
                case .OVERRIDE; return s, .OVERRIDE;
                case .IGNORE; return null, .IGNORE;
            }
        }
    }
    section := New(INISection);
    section.name = copy_string(name);
    array_add(*ini.sections, section);
    return section, .OVERRIDE;
}

ini_add_value :: (ini: *INI, section: *INISection, key: string, value: string) -> INIDupeBehavior {
    if !ini.case_sensitive {
        to_lower(key);
    }
    for p:section.props {
        if p.key == key {
            if ini.duplicate_behavior == .OVERRIDE {
                p.value = copy_string(value);
            }
            return ini.duplicate_behavior;
        }
    }
    prop := New(INIProperty);
    prop.key = copy_string(key);
    prop.value = copy_string(value);
    array_add(*section.props, prop);
    return .NONE;
}

ini_add_value :: (ini: *INI, section: string, key: string, value: string) -> INIDupeBehavior {
    sec := ini_add_section(ini, section, get_or_create=true);
    return ini_add_value(ini, sec, key, value);
}

ini_get_value :: (ini: *INI, section: string, key: string) -> string, bool {
    for sec:ini.sections {
        if sec.name == section {
            for prop:sec.props {
                if prop.key == key return prop.value, true;
            }
        }
    }
    return "", false;
}

ini_get_string :: ini_get_value;

ini_get_int :: (ini: *INI, section: string, key: string, $T : Type = int) -> T, bool {
    val, success := ini_get_value(ini, section, key);
    if !success return 0, false;
    value, s := parse_int(*val, T);
    return value, s;
}

ini_get_float :: (ini: *INI, section: string, key: string, $T : Type = float) -> T, bool {
    val, success := ini_get_value(ini, section, key);
    if !success return 0.0, false;
    v, s := parse_float(*val, T);
    return v, s;
}

#scope_file
#import "Basic";
#import "File";
#import "String";
#import "Text_File_Handler";
