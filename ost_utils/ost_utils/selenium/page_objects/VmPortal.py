from .Displayable import Displayable

class VmPortal(Displayable):

    def __init__(self, ovirt_driver):
        super(VmPortal, self).__init__(ovirt_driver)

    def is_displayed(self):
        return self.ovirt_driver.is_id_present('page-router-render-component') and not self.ovirt_driver.is_class_name_present('spinner')

    def get_displayable_name(self):
        return 'VM Portal'

    def get_vm_status(self, vm_name):
        return self.ovirt_driver.driver.find_element_by_id('vm-' + vm_name + '-status').text.strip()

