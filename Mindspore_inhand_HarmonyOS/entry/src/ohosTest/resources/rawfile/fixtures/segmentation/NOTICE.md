# Portrait Segmentation test fixture

person.jpg is the unchanged 3000x4000, 644016-byte photograph Jessica Meir full length portrait (1) by Robert Markowitz, NASA Johnson Space Center (NASA asset JSC2016-E-016505).

- Canonical revision: https://commons.wikimedia.org/w/index.php?title=File:Jessica_Meir_full_length_portrait_(1).jpg&oldid=948780982
- Original source: https://www.flickr.com/photos/nasa2explore/25538006340/
- Original bytes: https://live.staticflickr.com/1517/25538006340_5daeacdca6_o.jpg
- License: public domain in the United States as a work solely created by NASA (PD-USGov-NASA).
- SHA-256: D203D1DACD8E5976D27405E2932BBAF4E6FD1CD3B0F026FE6EC8AEF72E2E72AE

person_mask.png is a project-authored 3000x4000 binary alpha mask, SHA-256 12E92A228615D333E5791AF039A61842044DFEF43DC1DE963F9F56D71B10CAF7. It was authored independently from source-image pixels with fixed geometric foreground/background seeds and GrabCut, then visually reviewed. The production segmentation model and its output were not used to create the mask.
