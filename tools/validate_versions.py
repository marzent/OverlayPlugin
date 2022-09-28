import sys
import os.path
import xml.etree.ElementTree as ElementTree

BASE_DIR = os.path.join(os.path.dirname(__file__), "..")
PROJECTS = (
    "HtmlRenderer",
    "OverlayPlugin",
    "OverlayPlugin.Common",
    "OverlayPlugin.Core",
    "OverlayPlugin.Updater",
)


def get_version_from(project: str) -> str:
    proj_xml = ElementTree.parse(os.path.join(BASE_DIR, project, project + ".csproj"))
    return next(proj_xml.getroot().iter("Version")).text


versions = [get_version_from(project) for project in PROJECTS]

if len(set(versions)) == 1:
    print("Versions in sync!")
else:
    print("Found mismatching versions:", list(zip(PROJECTS, versions)))
    sys.exit(1)
