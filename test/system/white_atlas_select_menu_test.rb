require "application_system_test_case"
require "uri"
require "rack/utils"

class WhiteAtlasSelectMenuTest < ApplicationSystemTestCase
  test "consultation filter renders a themed combobox and submits the original select value" do
    visit consultations_url

    assert_selector "form.rc-consultation-filters button.rc-select-trigger[role='combobox']", count: 1
    assert_selector "form.rc-consultation-filters select[name='status'].rc-select-native", visible: :hidden
    trigger = find("form.rc-consultation-filters button.rc-select-trigger")
    assert_equal "false", trigger["aria-expanded"]

    trigger.click
    assert_equal "true", trigger["aria-expanded"]
    assert_selector ".rc-select-menu[role='listbox']:not([hidden])", count: 1
    assert_selector ".rc-select-menu [role='option']", minimum: 4

    find(".rc-select-menu [role='option']", text: "Upcoming", exact_text: true).click
    assert_equal "false", trigger["aria-expanded"]
    assert_equal "upcoming", page.evaluate_script("document.querySelector('select[name=status]').value")

    click_on "Apply filters"
    assert_equal "upcoming", Rack::Utils.parse_nested_query(URI.parse(page.current_url).query).fetch("status")
  end

  test "keyboard arrows, escape, home and end never invoke the browser-native select menu" do
    visit consultations_url
    trigger = find("form.rc-consultation-filters button.rc-select-trigger")

    trigger.send_keys(:arrow_down)
    assert_equal "true", trigger["aria-expanded"]
    assert_selector ".rc-select-menu:not([hidden])"
    trigger.send_keys(:escape)
    assert_equal "false", trigger["aria-expanded"]
    assert_equal "all", page.evaluate_script("document.querySelector('select[name=status]').value")

    trigger.send_keys(:arrow_down)
    trigger.send_keys(:end)
    trigger.send_keys(:enter)
    assert_equal "false", trigger["aria-expanded"]
    assert_equal "past", page.evaluate_script("document.querySelector('select[name=status]').value")
  end

  test "contextual menu is portalled outside clipping cards and stays within mobile viewport" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit consultations_url
    trigger = find("form.rc-consultation-filters button.rc-select-trigger")
    trigger.click

    geometry = page.evaluate_script(<<~JS)
      (() => {
        const popup = document.querySelector('.rc-select-menu:not([hidden])');
        const trigger = document.querySelector('.rc-select-trigger');
        const r = popup.getBoundingClientRect();
        return {
          isPortal: popup.parentElement === document.body,
          width: r.width, left: r.left, right: r.right,
          top: r.top, bottom: r.bottom, viewport: window.innerWidth,
          maxHeight: getComputedStyle(popup).maxHeight,
          nativeHidden: getComputedStyle(document.querySelector('select[name=status]')).opacity
        }
      })()
    JS

    assert_equal true, geometry["isPortal"]
    assert_operator geometry["left"], :>=, 0
    assert_operator geometry["right"], :<=, geometry["viewport"] + 1
    assert_operator geometry["top"], :>=, 0
    assert_operator geometry["bottom"], :<=, 844 + 1
    assert_equal "0", geometry["nativeHidden"]

    click_on "Clear"
    assert_no_selector ".rc-select-menu:not([hidden])"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "Turbo visits never duplicate enhanced selects or menus" do
    visit consultations_url
    assert_selector ".rc-select-trigger", count: 1
    visit root_url
    visit consultations_url
    assert_selector ".rc-select-trigger", count: 1
    assert_selector ".rc-select-menu", visible: :hidden, count: 1
  end
end
