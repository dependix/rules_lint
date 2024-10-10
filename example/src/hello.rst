rst = """
Some content.

Hello World
=======
Some more content!
"""
errors = restructuredtext_lint.lint(rst, 'myfile.py')
errors[0].line  # 5
errors[0].source  # myfile.py
errors[0].level  # 2
errors[0].type  # WARNING
errors[0].message  # Title underline too short.
errors[0].full_message  # Title underline too short.
                        #
                        # Hello World
                        # =======
