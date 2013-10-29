#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name       "opscode-push-jobs-client-windows"
maintainer "Opscode, Inc."
homepage   "http://www.opscode.com"

package_name    "opscode-push-jobs-client"
install_path    "c:\\opscode_pushy_build"
build_version   Omnibus::BuildVersion.new.semver
build_iteration 1

# Hacky but allows us to set the embedded chef version that is installed.
# Once omnibus-ruby supports proper software definition version overrides
# (either externally or at the project level) this can go away.
ENV['CHEF_GIT_REV'] ||= "master"

dependency "preparation"
dependency "ruby-windows"
dependency "ruby-windows-devkit"
dependency "chef-gem-windows"
dependency "libzmq-windows"
dependency "opscode-pushy-client-windows"
dependency "opscode-push-jobs-client-msi"
dependency "version-manifest"