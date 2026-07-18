import { layer, map, rule, writeToProfile } from 'karabiner.ts';

writeToProfile('ts', [
  rule('ansi backtick fix').manipulators([
    map('grave_accent_and_tilde').to('non_us_backslash'),
    map('non_us_backslash').to('grave_accent_and_tilde'),
  ]),

  rule('modifiers').manipulators([
    map('caps_lock').to('left_control', undefined, { lazy: true }).toIfAlone('escape'),
    map('left_command').to('left_command', undefined, { lazy: true }).toIfAlone('tab'),
    map('right_command').to('right_command', undefined, { lazy: true }).toIfAlone('delete_or_backspace'),
  ]),

  layer('tab').manipulators([
    map('h').to('left_arrow'),
    map('j').to('down_arrow'),
    map('k').to('up_arrow'),
    map('l').to('right_arrow'),

    map('u').to('open_bracket', 'shift'),
    map('i').to('close_bracket', 'shift'),
    map('o').to('9', 'shift'),
    map('p').to('0', 'shift'),

    map('n').to('open_bracket'),
    map('m').to('close_bracket'),
    map('comma').to('comma', 'shift'),
    map('period').to('period', 'shift'),
  ]),
])
