import unittest
from pathlib import Path

from tools.translation.validate_requirements_lock import validate_lock


LOCK = Path(__file__).with_name("requirements.lock.txt")


class RequirementsLockTest(unittest.TestCase):
    def test_lock_is_hashed_complete_and_gated_to_verified_host(self):
        result = validate_lock(LOCK, check_runtime=True)
        self.assertEqual(result["python"], "3.13.14")
        self.assertEqual(result["platform"], "win32")
        self.assertEqual(result["machine"], "AMD64")
        self.assertGreater(result["packages"], 20)


if __name__ == "__main__":
    unittest.main()
