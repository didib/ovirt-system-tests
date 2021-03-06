import logging

from .Displayable import Displayable

LOGGER = logging.getLogger(__name__)


class Grafana(Displayable):

    def __init__(self, ovirt_driver):
        super(Grafana, self).__init__(ovirt_driver)

    def is_displayed(self):
        return self.ovirt_driver.driver.find_element_by_xpath('//h1[text()="Welcome to Grafana"] | //span[text()="Welcome to Grafana"]').is_displayed()

    def get_displayable_name(self):
        return 'Grafana'

    def open_dashboard(self, menu, submenu):
        LOGGER.debug('Open dashboard ' + menu + '/' + submenu)
        self.ovirt_driver.xpath_wait_and_click('Grafana logo button', '//*[@class="sidemenu__logo"]')
        self.ovirt_driver.xpath_wait_and_click('Home button', '//div[@class="navbar"]//a[normalize-space()="Home"] | //button[normalize-space()="Home"]')
        self.ovirt_driver.xpath_wait_and_click(menu, f'//*[text() = "{menu}"]')
        self.ovirt_driver.xpath_wait_and_click(submenu, f'//*[text() = "{submenu}"]')

        self.ovirt_driver.wait_until('Breadcrumbs visible', self._is_breadcrumbs_visible, menu, submenu)

    def is_error_visible(self):
        return self.ovirt_driver.is_class_name_present('alert-error') and self.ovirt_driver.driver.find_element_by_class_name('alert-error').is_displayed()

    def _is_breadcrumbs_visible(self, menu, submenu):
        is_breadcrumb_menu_visible = self.ovirt_driver.driver.find_element_by_xpath(f'//div[@class="navbar-page-btn"]//a[text() = "{menu}"] | //button[text() = "{menu}"]')
        is_breadcrumb_submenu_visible = self.ovirt_driver.driver.find_element_by_xpath(f'//div[@class="navbar-page-btn"]//a[text() = "{submenu}"] | //button[text() = "{submenu}"]')
        return is_breadcrumb_menu_visible and is_breadcrumb_submenu_visible
