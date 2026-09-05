"""Strip-scanner vector suite — moved verbatim from the application's
utils/html_to_text_tests.mojo; every case is a frozen input/output pair.

Run: pixi run run-strip-test

origin: alugue-mojo-api utils/html_to_text_tests.mojo
"""

from std.sys import exit

from mojosearch.entities.html_to_text import strip_html_to_text


def check(cases: List[Tuple[String, String, String]]) -> Int:
    var fails = 0
    for case_index in range(len(cases)):
        var actual_text = strip_html_to_text(cases[case_index][0])
        var expected_text = cases[case_index][1]
        if actual_text != expected_text:
            fails += 1
            if fails <= 12:
                print(
                    "FAIL ["
                    + cases[case_index][2]
                    + "] in="
                    + cases[case_index][0]
                    + " want="
                    + expected_text
                    + " got="
                    + actual_text
                )
    return fails


def build_cases() -> List[Tuple[String, String, String]]:
    var cases = List[Tuple[String, String, String]]()
    cases.append(("", "", "empty_input_yields_empty_output"))
    cases.append(("   ", "", "whitespace_only_trims_to_empty"))
    cases.append(
        (
            "Cord\u00e3o de prata banhada a ouro. Novo<br>.<br><br>Aceito proposta <br><br>Entrego em qualquer lugar de Manaus. <br><br>Manda mensagem no Zap.<br><br>988311367<br><br>988311367",
            "Cord\u00e3o de prata banhada a ouro. Novo.Aceito proposta Entrego em qualquer lugar de Manaus. Manda mensagem no Zap.988311367988311367",
            "brazilian_ad_br_only_joins_and_trims",
        )
    )
    cases.append(
        (
            "G&G Im\u00f3veis",
            "G&amp;G Im\u00f3veis",
            "bare_ampersand_escaped_on_wire",
        )
    )
    cases.append(
        ("a &amp; b", "a &amp; b", "amp_semi_entity_roundtrip_unchanged")
    )
    cases.append(
        (
            "<script>alert(1)</script>hi",
            "hi",
            "script_content_dropped_tail_kept",
        )
    )
    cases.append(
        ("<style>p{}</style>hi", "hi", "style_content_dropped_tail_kept")
    )
    cases.append(
        (
            "'quote' \"dq\" <lt> &gt;",
            "&#39;quote&#39; &#34;dq&#34;  &gt;",
            "quotes_escaped_gt_entity_passthrough_unknown_tag_dropped",
        )
    )
    cases.append(
        (
            "  padded text  ",
            "padded text",
            "ascii_whitespace_both_sides_trimmed",
        )
    )
    cases.append(("a<!-- comment -->b", "ab", "comment_removed_glue"))
    cases.append(("line1\nline2", "line1\nline2", "internal_lf_passthrough"))
    cases.append(("<p>para</p>", "para", "p_tags_unwrap"))
    cases.append(("<b>bold</b>text", "boldtext", "b_tags_unwrap_adjacent_text"))
    cases.append(('<a href="x">link</a>', "link", "anchor_attr_text_kept_only"))
    cases.append(("<br/>self", "self", "br_solidus_selfclose_dropped"))
    cases.append(
        (
            "unclosed <div tag",
            "unclosed",
            "unclosed_div_attr_eof_dropped_keeps_text",
        )
    )
    cases.append(
        (
            "1 < 2 and 3 > 2",
            "1 &lt; 2 and 3 &gt; 2",
            "numeric_free_text_with_lt_gt_escaped",
        )
    )
    cases.append(
        ("&nbsp;NBSP&nbsp;", "NBSP", "nbsp_entities_trimmed_as_unicode_space")
    )
    cases.append(("caf&eacute;", "caf\u00e9", "eacute_named_entity_decodes"))
    cases.append(
        (
            '<div class="a<b">attr gt</div>',
            "attr gt",
            "embedded_lt_in_quoted_attr_tolerated",
        )
    )
    cases.append(
        (
            "&#72;&#101;&#108;&#108;&#111;",
            "Hello",
            "decimal_numeric_refs_spell_hello",
        )
    )
    cases.append(
        (
            "<SCRIPT>x</SCRIPT>after",
            "after",
            "uppercase_script_closed_case_insensitive",
        )
    )
    cases.append(
        ("<textarea>t</textarea>", "t", "textarea_rcdata_content_kept")
    )
    cases.append(("<TITLE>t</TITLE>", "", "title_skip_content_suppressed"))
    cases.append(
        ("\u00a0wide space\u00a0", "wide space", "nbsp_wrapped_text_trimmed")
    )
    cases.append(('a<b c="d>e">f', "af", "quoted_value_swallows_embedded_gt"))
    cases.append(
        ("<3 hearts", "&lt;3 hearts", "lt_before_digit_stays_literal_text")
    )
    cases.append(("a< b", "a&lt; b", "lt_followed_by_space_stays_literal"))
    cases.append(
        (
            "sep<ul><li>one</li><li>two</li></ul>sep",
            "seponetwosep",
            "ul_li_list_concatenation_no_separators",
        )
    )
    cases.append(("a\rb", "a\nb", "lone_cr_converts_to_lf"))
    cases.append(("a\n\rb", "a\n\nb", "cr_after_lf_stays_second_lf"))
    cases.append(("a\r\nb", "a\nb", "crlf_collapses_to_single_lf"))
    cases.append(
        ("<script>x</script", "", "unterminated_script_closer_consumes_rest")
    )
    cases.append(
        (
            "a<textarea>x</textarea",
            "ax&lt;/textarea",
            "unterminated_textarea_closer_leaks_literal_tail",
        )
    )
    cases.append(("<![CDATA[x]]>b", "b", "cdata_construct_dropped"))
    cases.append(("a<!--x--!>b", "ab", "bang_bang_degenerate_comment_close"))
    cases.append(("a<!-->b", "ab", "abrupt_comment_open_close"))
    cases.append(("a<!x>b", "ab", "bang_letter_bogus_scan"))
    cases.append(
        ("a<?php echo;>b", "ab", "php_processing_instruction_lookalike_bogus")
    )
    cases.append(("</3>b", "b", "endtag_digit_bogus"))
    cases.append(("</ >b", "b", "endtag_space_bogus"))
    cases.append(("<div class=a>b</div>", "b", "unquoted_class_attr_skipped"))
    cases.append(("a&#37;b", "a%b", "percent_numeric_ref_decodes"))
    cases.append(("\r\n in text \r\n", "in text", "crlf_padding_trimmed_off"))
    cases.append(("a\x0b\x0cb", "a\x0b\x0cb", "vtab_formfeed_passthrough"))
    cases.append(("<a href='x' y=z>t</a>", "t", "two_attrs_anchor_skipped"))
    cases.append(("<p CLASS=x>t</p>", "t", "uppercase_class_attr_processed"))
    cases.append(("<P/>x", "x", "uppercase_p_solidus_selfclose"))
    cases.append(("</p>x", "x", "stray_mid_text_end_tag_transparent"))
    cases.append(
        ("a<em>b<strong>c</em>d", "abcd", "misnested_em_strong_flat_concat")
    )
    cases.append(
        (
            'a<DIV\nCLASS="q"\n>y</DIV>z',
            "ayz",
            "multiline_uppercase_div_attr_scan",
        )
    )
    cases.append(
        (
            '<script \n type="x">s</script>t',
            "t",
            "newline_inside_script_starttag_ok",
        )
    )
    cases.append(("a<Script>x</Script>b", "ab", "mixed_case_script_closes"))
    cases.append(
        (
            '<a href="unterminated',
            "",
            "unterminated_double_quoted_value_eats_rest",
        )
    )
    cases.append(
        (
            "<a href='x>b</a>",
            "",
            "gt_in_unterminated_single_quoted_href_eats_all",
        )
    )
    cases.append(("<b><b>n</b></b>", "n", "nested_same_bold_tag_flattens"))
    cases.append(("a</b>b", "ab", "stray_middle_end_tag_transparent"))
    cases.append(("<image src=x>i</image>", "i", "image_tag_pair_transparent"))
    cases.append(("&#x0;", "\ufffd", "zero_numeric_ref_replacement_char"))
    cases.append(("&#;", "&amp;#;", "hash_semicolon_alone_amp_literal"))
    cases.append(("&#x;", "&amp;#x;", "hash_x_without_digits_amp_literal"))
    cases.append(("&;", "&amp;;", "amp_semicolon_alone_literal"))
    cases.append(("&", "&amp;", "lone_ampersand_amp_literal"))
    cases.append(
        ("&&amp;&", "&amp;&amp;&amp;", "amp_entity_amp_chain_each_handled")
    )
    cases.append(("a&notb", "a\u00acb", "not_legacy_bare_record_hit"))
    cases.append(("a&notib", "a\u00acib", "not_legacy_then_plain_remainder"))
    cases.append(("a&nx;", "a&amp;nx;", "unknown_nx_name_amp_preserved"))
    cases.append(("a&#x00E9;b", "a\u00e9b", "lowercase_hex_e9_decodes_acute"))
    cases.append(("a&#13;b", "a&#13;b", "numeric_cr_ref_wires_back_escaped"))
    cases.append(
        ("a&#38;#38;b", "a&amp;#38;b", "numeric_amp_ref_double_shape_preserved")
    )
    cases.append(("a&Tab;b", "a\tb", "tab_named_entity_decodes_to_tab"))
    cases.append(("a&NewLine;b", "a\nb", "newline_named_entity_decodes"))
    cases.append(("a&quotb", "a&#34;b", "quot_legacy_without_semicolon"))
    cases.append(("a&semi;b", "a;b", "semi_entity_decodes"))
    cases.append(
        (
            "<textarea>x</TEXTAREA >y",
            "xy",
            "textarea_uppercase_closer_space_form",
        )
    )
    cases.append(
        (
            "<textarea>x</textarea\t>y",
            "xy",
            "tab_between_name_and_bracket_closer",
        )
    )
    cases.append(
        (
            '<script>x</script foo="a>b">y',
            "y",
            "closer_attribute_containing_quoted_gt",
        )
    )
    cases.append(
        ('<div a=">">t</div>', "t", "div_attr_value_contains_gt_doublequote")
    )
    cases.append(
        ("<div a='>'>t</div>", "t", "div_attr_value_contains_gt_singlequote")
    )
    cases.append(
        (
            "<iframe>a<iframe>b</iframe>c</iframe>d",
            "cd",
            "iframe_nested_counter_suppresses_inner",
        )
    )
    cases.append(
        (
            'a<noscript>x</noscript style="q">b',
            "ab",
            "noscript_closer_with_stray_attr",
        )
    )
    cases.append(
        ("<TITLE></TITLE >a", "a", "empty_title_immediate_close_then_text")
    )
    cases.append(
        (
            "<textarea>a</textarea>b</textarea>c",
            "abc",
            "textarea_duplicate_closers_text_positions_kept",
        )
    )
    cases.append(("a<b/>c", "ac", "tag_slash_close_bare"))
    cases.append(("a<b />c", "ac", "tag_space_slash_close"))
    cases.append(
        (
            "<svg><script/xlink:href=data:x</script></svg>",
            "",
            "svg_script_slash_attr_swallow",
        )
    )
    cases.append(
        (
            'keep<b style="color:red">red</b>',
            "keepred",
            "inline_style_attr_transparent",
        )
    )
    cases.append(
        (
            "keep<a href='x>b",
            "keep",
            "keep_before_unterminated_single_quote_value",
        )
    )
    cases.append(
        (
            'keep<a href="x',
            "keep",
            "keep_before_unterminated_double_quote_value",
        )
    )
    cases.append(
        ("keep<!-- unterminated", "keep", "keep_before_unterminated_comment")
    )
    cases.append(("keep<div", "keep", "keep_before_unterminated_tag"))
    cases.append(
        ("keep</div x", "keep", "keep_before_unterminated_endtag_junk")
    )
    cases.append(("a&#xE934;b", "a\ue934b", "hex_above_plane_char_passes"))
    cases.append(("a&#x80;b", "a\u20acb", "hex_80_row_maps_to_euro_sign"))
    cases.append(("a&#151;b", "a\u2014b", "decimal_151_mdash_via_win1252_row"))
    cases.append(("a&#0;b", "a\ufffdb", "zero_codepoint_fffd_substitution"))
    cases.append(("a&#x10FFFF;b", "a\U0010ffffb", "ten_ffff_max_rune_survives"))
    cases.append(("a&#xD800;b", "a\ufffdb", "d800_surrogate_to_fffd"))
    cases.append(("AT&T", "AT&amp;T", "plain_at_ampersand_brand_escaped"))
    cases.append(("a&AMP b", "a&amp; b", "amp_uppercase_formal_semicolon"))
    cases.append(("a&amp b", "a&amp; b", "amp_legacy_bare_then_space"))
    cases.append(("a&ltb", "a&lt;b", "ltb_legacy_three_letters"))
    cases.append(("a&#38 b", "a&amp; b", "numeric_38_bare_then_space_boundary"))
    cases.append(
        ("&#38;amp;", "&amp;amp;", "numeric_38_then_entity_text_escaped_once")
    )
    cases.append(("a&ampx;b", "a&amp;x;b", "ampx_bare_partial_then_x_literal"))
    cases.append(("a&AMP;b", "a&amp;b", "amp_uppercase_exact_semicolon"))
    cases.append(("a&#X41;b", "aAb", "uppercase_hex_marker_X41"))
    cases.append(("x < 100", "x &lt; 100", "space_then_lt_space_literal"))
    cases.append(("x <100", "x &lt;100", "lt_attached_digits_literal_escaped"))
    cases.append(
        (
            "pre\u00e7o <1000 e >2000",
            "pre\u00e7o &lt;1000 e &gt;2000",
            "price_sentence_ptbr_escapes",
        )
    )
    cases.append(("<b><i>nest</i></b>", "nest", "simple_bi_nest_unwrap"))
    cases.append(
        ("<noscript>ns</noscript>after", "after", "noscript_route_close_after")
    )
    cases.append(
        ("<iframe>ifr</iframe>after", "after", "iframe_route_close_after")
    )
    cases.append(
        ("<object>ob</object>after", "after", "object_route_close_after")
    )
    cases.append(
        (
            "<title>a<title>b</title>c",
            "c",
            "duplicated_title_skips_to_final_tail",
        )
    )
    cases.append(
        (
            "<script>a<script>b</script>c",
            "c",
            "nested_script_inner_closes_then_c",
        )
    )
    cases.append(("<TITLE>t</TITLE >x", "x", "title_closer_spaced_uppercase"))
    cases.append(("</title>x", "x", "stray_title_endtag_dropped"))
    cases.append(
        ("a<textarea></textarea>b", "ab", "textarea_empty_immediate_close_ab")
    )
    cases.append(
        ("a<textarea/>b", "ab", "textarea_solidus_selfclose_nothing_suppressed")
    )
    cases.append(("<br\n/>x", "x", "br_newline_before_solidus_close"))
    cases.append(
        ("<div\nclass=x>y</div>", "y", "div_newline_before_class_attr")
    )
    cases.append(
        ("a<b>unclosed", "aunclosed", "unclosed_b_keeps_trailing_text")
    )
    cases.append(("a&notb", "a\u00acb", "legacy_not_repeat_regression"))
    cases.append(("<b><i><u>x</u></i></b>y", "xy", "triple_nest_biu_unwrap"))
    cases.append(
        ("<div><div><p>d</p></div></div>e", "de", "div_div_p_nest_unwrap")
    )
    cases.append(
        (
            "<script>a<script>b</script>c</script>d",
            "cd",
            "script_nested_two_deep_cd",
        )
    )
    cases.append(
        (
            "<style>s</style><STYLE>t</STYLE>u",
            "u",
            "style_then_uppercase_style_then_u",
        )
    )
    cases.append(("a<!--x--><!--y-->b", "ab", "adjacent_comments_removed"))
    cases.append(
        (
            "<!-- tags <div> inside -->t",
            "t",
            "comment_with_markup_inside_removed",
        )
    )
    cases.append(
        ("<ul><li>1<li>2<li>3</ul>end", "123end", "implicit_li_sequence_concat")
    )
    cases.append(
        ("<script><!-- c --></script>x", "x", "script_with_html_comment_inside")
    )
    cases.append(
        ("<script>if(a<b){y}</script>z", "z", "script_if_expr_with_lt")
    )
    cases.append(
        (
            '<style>@import url("</sty");</style>w',
            "w",
            "style_false_closer_fragment_in_string",
        )
    )
    cases.append(
        (
            "<textarea>a</textarea><textarea>b</textarea>c",
            "abc",
            "sequential_textareas_concat",
        )
    )
    cases.append(
        (
            "<PLAINTEXT><b>p&</PLAINTEXT>ignored",
            "&lt;b&gt;p&amp;&lt;/PLAINTEXT&gt;ignored",
            "plaintext_dump_literal_tags_to_eof",
        )
    )
    cases.append(
        (
            "<XMP>&lt;&amp;</XMP>tail",
            "&amp;lt;&amp;amp;tail",
            "xmp_raw_text_escapes_never_unescapes",
        )
    )
    cases.append(
        ("<noembed>&amp;q</noembed>r", "r", "noembed_entities_never_shown")
    )
    cases.append(
        (
            "<noframes>hidden</noframes>visible",
            "visible",
            "noframes_hidden_visible_toggle",
        )
    )
    cases.append(
        (
            "<plaintext>plain&nbsp;text",
            "plain&amp;nbsp;text",
            "plaintext_entities_stay_literal_escaped",
        )
    )
    cases.append(
        ("<title/>a</title>b", "b", "title_slf_then_real_title_keeps_b")
    )
    cases.append(("<iframe/>gone", "", "iframe_slf_still_opens_raw_swallow"))
    cases.append(("<script/>sv", "", "script_slf_still_opens_raw_swallow"))
    cases.append(("<noscript/>ns", "", "noscript_slf_still_counts_skip"))
    cases.append(
        (
            "<textarea/>t e</textarea>u",
            "t eu",
            "textarea_slf_content_until_real_closer",
        )
    )
    cases.append(
        (
            "<object>a<object>b</object>c</object>d",
            "d",
            "object_nested_deep_closes_last",
        )
    )
    cases.append(
        (
            "<object><!--x-->hid</object>shown",
            "shown",
            "object_with_comment_hidden_shown",
        )
    )
    cases.append(("<object>a</OBJECT>b", "b", "object_uppercase_closer_mixed"))
    cases.append(("</noembed>x", "x", "stray_noembed_endtag_dropped"))
    cases.append(
        (
            "a<title>T1</title>b<title>T2</title>c",
            "abc",
            "alternating_titles_positions_kept",
        )
    )
    cases.append(("a<!--->b", "ab", "triple_dash_abrupt_comment_close"))
    cases.append(("<!--aa=b-->t2", "t2", "comment_body_attrlike_t2"))
    cases.append(
        ("<! -->drop>t", "drop&gt;t", "bang_space_declaration_drops_through_gt")
    )
    cases.append(
        (
            "<!-- unterminated <!-- inner -->tail",
            "tail",
            "unterminated_comment_inner_dd_tail",
        )
    )
    cases.append(("</ div>t", "t", "spaced_endtag_bogus_drop"))
    cases.append(("<>x", "&lt;&gt;x", "angle_angle_pair_literal_out"))
    cases.append(("<", "&lt;", "lone_lt_at_eof_literal"))
    cases.append(
        (
            "<bogus q='>'/>more-tail",
            "more-tail",
            "bogus_attr_quoted_gt_slf_more_tail",
        )
    )
    cases.append(("&#0000065;", "A", "padded_decimal_zeros_a"))
    cases.append(("&#x000041;X", "AX", "padded_hex_zeros_ax"))
    cases.append(("&#Xff;", "\u00ff", "short_upper_Xff_y_diaeresis"))
    cases.append(
        ("&#21474836470;", "\ufffd", "enormous_decimal_overflows_to_fffd")
    )
    cases.append(("&#x10FFFE;", "\U0010fffe", "ten_ffffe_noncharacter_kept"))
    cases.append(
        (
            "&#128;&#142;&#159;",
            "\u20ac\u017d\u0178",
            "win1252_high_trio_euro_zcaron_ydiaeresis",
        )
    )
    cases.append(
        (
            "&#130;&#145;&#148;",
            "\u201a\u2018\u201d",
            "win1252_low_trio_curly_quotes",
        )
    )
    cases.append(("&#65&#66;", "AB", "adjacent_decimal_refs_no_semicolons_ab"))
    cases.append(("a&#10;b", "a\nb", "numeric_ten_lf_decode"))
    cases.append(("&#13;\n", "&#13;", "leading_cr_entity_then_lf_trimmed"))
    cases.append(
        (
            "x&NotEqualTilde;y",
            "x\u2242\u0338y",
            "entity2_pair_notequaltilde_two_runes",
        )
    )
    cases.append(
        (
            "&ThisEntityNameIsWayBeyondTableWidthZZ;q",
            "&amp;ThisEntityNameIsWayBeyondTableWidthZZ;q",
            "oversized_name_total_miss_full_echo",
        )
    )
    cases.append(("&time", "&amp;time", "time_legacy_name_miss_amp_kept"))
    cases.append(("&notin", "\u00acin", "notin_legacy_crosses_into_word"))
    cases.append(
        (
            "\u0081-\u009d-bytes",
            "\u0081-\u009d-bytes",
            "raw_c1_bytes_81_9d_passthrough",
        )
    )
    cases.append(
        (
            "emoji \U0001f389 passthrough",
            "emoji \U0001f389 passthrough",
            "emoji_passthrough_intact",
        )
    )
    cases.append(("\u3000x\u3000", "x", "ideographic_space_trimmed_at_ends"))
    cases.append(
        ("\u200bx\u200b", "\u200bx\u200b", "zwsp_is_not_unicode_space")
    )
    cases.append(
        ("a\r\r\nb\n\rc d", "a\n\nb\n\nc d", "cr_cluster_variants_mapping")
    )
    cases.append(("\ronly\r", "only", "cr_only_wrapped_trims_to_only"))
    cases.append(
        ("<img src=u alt='a>>b'/>z", "z", "img_alt_value_with_gt_gt_solidus_z")
    )
    cases.append(('<a b = "q">v</a>', "v", "spaces_around_equals_attr_scan"))
    cases.append(("<div/=x>y", "y", "slash_before_attr_name_tolerated"))
    cases.append(
        ("<span\t\ndata-x=1>y</span>", "y", "span_tabs_datax_unquoted_value")
    )
    cases.append(
        (
            "<a href=unquoted-net/>x",
            "x",
            "unquoted_net_value_trailing_slash_still_closes",
        )
    )
    cases.append(
        ("txt<a href='k", "txt", "txt_before_eof_quote_anchor_keeps_txt")
    )
    cases.append(("keep<style>sst", "keep", "unterminated_style_after_keep"))
    cases.append(("keep<tx", "keep", "partial_lowercase_tagname_eof_swallowed"))
    cases.append(("x</", "x&lt;/", "eof_after_endtag_open_literal"))
    cases.append(
        (
            "\u00abguillemet\u00bb \u00fcn\u00efc\u00f6d\u00e9 \u2714",
            "\u00abguillemet\u00bb \u00fcn\u00efc\u00f6d\u00e9 \u2714",
            "latin1_extras_checkmark_passthrough",
        )
    )
    cases.append(
        (
            "&CounterClockwiseContourIntegral;tail",
            "\u2233tail",
            "counterclockwisecontourintegral_longest_name_hit",
        )
    )
    cases.append(
        ("line\ttab\tsep", "line\ttab\tsep", "interior_tabs_preserved")
    )
    cases.append(
        ("&frac12;+&frac12;", "\u00bd+\u00bd", "frac12_vulgar_half_decode")
    )
    return cases.copy()


def run_suite():
    var cases = build_cases()
    var fails = check(cases)
    print("cases:", len(cases), "fails:", fails)
    if fails > 0:
        exit(1)


def main():
    run_suite()
